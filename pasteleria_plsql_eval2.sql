
SET SERVEROUTPUT ON;

CREATE TABLE log_eventos (
  id_log     NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  fecha      DATE DEFAULT SYSDATE,
  usuario    VARCHAR2(50),
  tabla      VARCHAR2(30),
  operacion  VARCHAR2(30),
  detalle    VARCHAR2(200)
);

CREATE OR REPLACE FUNCTION fn_total_pedido (p_id_pedido IN NUMBER)
RETURN NUMBER IS
  v_total NUMBER;
BEGIN
  SELECT NVL(SUM(cantidad * precio_unitario), 0)
    INTO v_total
    FROM detalle_pedidos
   WHERE id_pedido = p_id_pedido;
  RETURN v_total;
END fn_total_pedido;
/

CREATE OR REPLACE FUNCTION fn_total_pendiente
RETURN NUMBER IS
  v_total NUMBER;
BEGIN
  SELECT NVL(SUM(d.cantidad * d.precio_unitario), 0)
    INTO v_total
    FROM detalle_pedidos d
    JOIN pedidos p ON p.id_pedido = d.id_pedido
   WHERE p.estado = 'PENDIENTE';
  RETURN v_total;
END fn_total_pendiente;
/

CREATE OR REPLACE FUNCTION fn_stock_suficiente (
  p_id_producto IN NUMBER,
  p_cantidad    IN NUMBER
) RETURN NUMBER IS
  v_faltantes NUMBER;
BEGIN
  SELECT COUNT(*)
    INTO v_faltantes
    FROM receta r
    JOIN ingredientes i ON i.id_ingrediente = r.id_ingrediente
   WHERE r.id_producto = p_id_producto
     AND i.stock_actual < r.cantidad_requerida * p_cantidad;
  RETURN CASE WHEN v_faltantes = 0 THEN 1 ELSE 0 END;
END fn_stock_suficiente;
/

CREATE OR REPLACE PROCEDURE sp_listar_pedidos_pendientes IS
BEGIN
  DBMS_OUTPUT.PUT_LINE('--- PEDIDOS PENDIENTES ---');
  FOR r IN (SELECT p.id_pedido,
                   c.nombre || ' ' || c.apellido AS cliente,
                   p.fecha_entrega
              FROM pedidos p
              JOIN clientes c ON c.id_cliente = p.id_cliente
             WHERE p.estado = 'PENDIENTE'
             ORDER BY p.fecha_entrega) LOOP
    DBMS_OUTPUT.PUT_LINE('Pedido ' || r.id_pedido || ' | ' || r.cliente ||
      ' | Entrega: ' || TO_CHAR(r.fecha_entrega, 'DD/MM/YYYY') ||
      ' | Total: $' || TO_CHAR(fn_total_pedido(r.id_pedido), 'FM999,999,990'));
  END LOOP;
END sp_listar_pedidos_pendientes;
/

CREATE OR REPLACE PROCEDURE sp_actualizar_estado_pedido (
  p_id_pedido IN NUMBER,
  p_estado    IN VARCHAR2
) IS
BEGIN
  IF p_estado NOT IN ('PENDIENTE','EN PREPARACION','LISTO','ENTREGADO','CANCELADO') THEN
    RAISE_APPLICATION_ERROR(-20010, 'Estado no valido: ' || p_estado);
  END IF;

  UPDATE pedidos SET estado = p_estado WHERE id_pedido = p_id_pedido;

  IF SQL%ROWCOUNT = 0 THEN
    RAISE_APPLICATION_ERROR(-20011, 'El pedido ' || p_id_pedido || ' no existe');
  END IF;
END sp_actualizar_estado_pedido;
/

CREATE OR REPLACE PROCEDURE sp_descontar_ingredientes (p_id_pedido IN NUMBER) IS
BEGIN
  FOR d IN (SELECT id_producto, cantidad
              FROM detalle_pedidos
             WHERE id_pedido = p_id_pedido) LOOP
    UPDATE ingredientes i
       SET i.stock_actual = i.stock_actual -
           (SELECT r.cantidad_requerida * d.cantidad
              FROM receta r
             WHERE r.id_producto    = d.id_producto
               AND r.id_ingrediente = i.id_ingrediente)
     WHERE EXISTS (SELECT 1
                     FROM receta r
                    WHERE r.id_producto    = d.id_producto
                      AND r.id_ingrediente = i.id_ingrediente);
  END LOOP;
END sp_descontar_ingredientes;
/

CREATE OR REPLACE PROCEDURE sp_reponer_stock_bajo (
  p_factor        IN  NUMBER DEFAULT 3,
  p_reabastecidos OUT NUMBER
) IS
BEGIN
  UPDATE ingredientes
     SET stock_actual = stock_minimo * p_factor
   WHERE stock_actual < stock_minimo;
  p_reabastecidos := SQL%ROWCOUNT;
END sp_reponer_stock_bajo;
/

CREATE OR REPLACE PACKAGE pkg_pasteleria AS
  c_estado_pendiente   CONSTANT VARCHAR2(20) := 'PENDIENTE';
  c_estado_preparacion CONSTANT VARCHAR2(20) := 'EN PREPARACION';
  c_estado_entregado   CONSTANT VARCHAR2(20) := 'ENTREGADO';

  FUNCTION  total_con_iva (p_id_pedido IN NUMBER) RETURN NUMBER;
  PROCEDURE confirmar_pedido (p_id_pedido IN NUMBER);
  PROCEDURE entregar_pedido  (p_id_pedido IN NUMBER);
  PROCEDURE resumen_ventas;
END pkg_pasteleria;
/

CREATE OR REPLACE PACKAGE BODY pkg_pasteleria AS
  c_iva           CONSTANT NUMBER := 0.19;
  g_inicio_sesion DATE;

  PROCEDURE registrar_log (p_operacion IN VARCHAR2, p_detalle IN VARCHAR2) IS
  BEGIN
    INSERT INTO log_eventos (usuario, tabla, operacion, detalle)
    VALUES (USER, 'PEDIDOS', p_operacion, p_detalle);
  END registrar_log;

  FUNCTION validar_stock_pedido (p_id_pedido IN NUMBER) RETURN BOOLEAN IS
  BEGIN
    FOR d IN (SELECT id_producto, cantidad
                FROM detalle_pedidos
               WHERE id_pedido = p_id_pedido) LOOP
      IF fn_stock_suficiente(d.id_producto, d.cantidad) = 0 THEN
        RETURN FALSE;
      END IF;
    END LOOP;
    RETURN TRUE;
  END validar_stock_pedido;

FUNCTION total_con_iva (p_id_pedido IN NUMBER) RETURN NUMBER IS
  BEGIN
    RETURN ROUND(fn_total_pedido(p_id_pedido) * (1 + c_iva));
  END total_con_iva;

  PROCEDURE confirmar_pedido (p_id_pedido IN NUMBER) IS
  BEGIN
    IF NOT validar_stock_pedido(p_id_pedido) THEN
      RAISE_APPLICATION_ERROR(-20020,
        'Stock de ingredientes insuficiente para el pedido ' || p_id_pedido);
    END IF;
    sp_descontar_ingredientes(p_id_pedido);
    sp_actualizar_estado_pedido(p_id_pedido, c_estado_preparacion);
    registrar_log('CONFIRMAR', 'Pedido ' || p_id_pedido || ' confirmado');
  END confirmar_pedido;

  PROCEDURE entregar_pedido (p_id_pedido IN NUMBER) IS
  BEGIN
    sp_actualizar_estado_pedido(p_id_pedido, c_estado_entregado);
    registrar_log('ENTREGAR', 'Pedido ' || p_id_pedido || ' entregado');
  END entregar_pedido;

  PROCEDURE resumen_ventas IS
  BEGIN
    DBMS_OUTPUT.PUT_LINE('--- RESUMEN POR ESTADO (sesion desde ' ||
                         TO_CHAR(g_inicio_sesion, 'HH24:MI:SS') || ') ---');
    FOR r IN (SELECT estado,
                     COUNT(*) AS pedidos,
                     SUM(fn_total_pedido(id_pedido)) AS total
                FROM pedidos
               GROUP BY estado
               ORDER BY estado) LOOP
      DBMS_OUTPUT.PUT_LINE(RPAD(r.estado, 16) || r.pedidos || ' pedido(s) | $' ||
                           TO_CHAR(r.total, 'FM999,999,990'));
    END LOOP;
  END resumen_ventas;

BEGIN
  g_inicio_sesion := SYSDATE;
END pkg_pasteleria;
/

CREATE OR REPLACE TRIGGER trg_pedidos_auditoria
AFTER INSERT OR UPDATE OR DELETE ON pedidos
BEGIN
  INSERT INTO log_eventos (usuario, tabla, operacion, detalle)
  VALUES (USER, 'PEDIDOS',
          CASE WHEN INSERTING THEN 'INSERT'
               WHEN UPDATING  THEN 'UPDATE'
               ELSE 'DELETE' END,
          'Sentencia ejecutada sobre pedidos');
END trg_pedidos_auditoria;
/

CREATE OR REPLACE TRIGGER trg_pedidos_estado
BEFORE UPDATE OF estado ON pedidos
FOR EACH ROW
BEGIN
  IF :OLD.estado = 'ENTREGADO' AND :NEW.estado <> 'ENTREGADO' THEN
    RAISE_APPLICATION_ERROR(-20030,
      'El pedido ' || :OLD.id_pedido || ' ya fue entregado y no puede cambiar de estado');
  END IF;
END trg_pedidos_estado;
/

CREATE OR REPLACE TRIGGER trg_detalle_validar
BEFORE INSERT OR UPDATE ON detalle_pedidos
FOR EACH ROW
BEGIN
  IF :NEW.cantidad IS NULL OR :NEW.cantidad <= 0 THEN
    RAISE_APPLICATION_ERROR(-20031, 'La cantidad debe ser mayor a 0');
  END IF;

  IF :NEW.precio_unitario IS NULL THEN
    SELECT precio INTO :NEW.precio_unitario
      FROM productos
     WHERE id_producto = :NEW.id_producto;
  END IF;
END trg_detalle_validar;
/

CREATE OR REPLACE TRIGGER trg_ingredientes_alerta
AFTER UPDATE OF stock_actual ON ingredientes
FOR EACH ROW
WHEN (NEW.stock_actual < NEW.stock_minimo)
BEGIN
  INSERT INTO log_eventos (usuario, tabla, operacion, detalle)
  VALUES (USER, 'INGREDIENTES', 'ALERTA_STOCK',
          :NEW.nombre || ': ' || :NEW.stock_actual || ' ' || :NEW.unidad_medida ||
          ' (minimo ' || :NEW.stock_minimo || ')');
END trg_ingredientes_alerta;
/
  
SELECT id_pedido, estado, fn_total_pedido(id_pedido) AS total
  FROM pedidos;

SELECT fn_total_pendiente AS total_pendiente FROM dual;

SELECT id_producto, nombre, fn_stock_suficiente(id_producto, 5) AS alcanza_para_5
  FROM productos;

EXEC sp_listar_pedidos_pendientes;

EXEC pkg_pasteleria.confirmar_pedido(1);
SELECT nombre, stock_actual FROM ingredientes ORDER BY id_ingrediente;
SELECT pkg_pasteleria.total_con_iva(1) AS total_con_iva FROM dual;
EXEC pkg_pasteleria.resumen_ventas;

UPDATE ingredientes SET stock_actual = 2 WHERE id_ingrediente = 5;
DECLARE
  v_reabastecidos NUMBER;
BEGIN
  sp_reponer_stock_bajo(3, v_reabastecidos);
  DBMS_OUTPUT.PUT_LINE('Ingredientes repuestos: ' || v_reabastecidos);
END;
/

BEGIN
  sp_actualizar_estado_pedido(3, 'PENDIENTE');
END;
/

INSERT INTO detalle_pedidos (id_pedido, id_producto, cantidad, precio_unitario)
VALUES (1, 2, 0, NULL);

SELECT * FROM log_eventos ORDER BY id_log;

COMMIT;
