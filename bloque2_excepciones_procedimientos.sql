/* =========================================================================
   BDY1103 - Evaluación Parcial N°1 - Taller de Base de Datos
   BLOQUE 2: Excepciones, Procedimiento, Función, Package y Trigger
   Autor: (compañero de equipo)
   Rama sugerida: excepciones-procedimientos

   NOTA IMPORTANTE:
   Este script asume una estructura de tablas típica para un sistema de
   pedidos con control de stock por receta. Si el proyecto ya tiene tablas
   creadas con otros nombres, AJUSTA los nombres de tabla/columna en este
   script para que calcen con el esquema real (no dupliques tablas que ya
   existan). Las sentencias CREATE TABLE están marcadas y se pueden omitir
   si esas tablas ya existen.
   ========================================================================= */


/* =========================================================================
   0. TABLAS DE APOYO (omitir si ya existen en el proyecto)
   ========================================================================= */

-- Ingredientes con stock
CREATE TABLE ingredientes (
    id_ingrediente   NUMBER PRIMARY KEY,
    nombre           VARCHAR2(100) NOT NULL,
    stock_actual     NUMBER NOT NULL,
    unidad_medida    VARCHAR2(20)
);

-- Productos del menú
CREATE TABLE productos (
    id_producto      NUMBER PRIMARY KEY,
    nombre           VARCHAR2(100) NOT NULL,
    precio           NUMBER(10,2) NOT NULL
);

-- Receta: cuánto de cada ingrediente lleva un producto
CREATE TABLE receta_detalle (
    id_producto      NUMBER REFERENCES productos(id_producto),
    id_ingrediente   NUMBER REFERENCES ingredientes(id_ingrediente),
    cantidad_requerida NUMBER NOT NULL,
    PRIMARY KEY (id_producto, id_ingrediente)
);

-- Pedidos
CREATE TABLE pedidos (
    id_pedido        NUMBER PRIMARY KEY,
    id_cliente       NUMBER,
    fecha_pedido     DATE DEFAULT SYSDATE,
    estado           VARCHAR2(20) DEFAULT 'PENDIENTE',
    total            NUMBER(10,2)
);

-- Detalle del pedido: qué productos y cuántos pidió
CREATE TABLE detalle_pedido (
    id_pedido        NUMBER REFERENCES pedidos(id_pedido),
    id_producto      NUMBER REFERENCES productos(id_producto),
    cantidad         NUMBER NOT NULL,
    PRIMARY KEY (id_pedido, id_producto)
);

-- Tabla de auditoría para el trigger
CREATE TABLE auditoria_stock (
    id_auditoria     NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_ingrediente   NUMBER,
    stock_anterior   NUMBER,
    stock_nuevo      NUMBER,
    fecha_cambio     DATE DEFAULT SYSDATE,
    usuario_bd       VARCHAR2(50)
);


/* =========================================================================
   1. EXCEPCIONES
   ========================================================================= */

-- 1.a) Excepción predefinida de Oracle: NO_DATA_FOUND
--      Se usa cuando se busca un pedido/cliente/producto que no existe.
--      (se demuestra su uso dentro del procedimiento y la función más abajo)

-- 1.b) Excepción personalizada: e_stock_insuficiente
--      Se declara a nivel de bloque (ver PR_PROCESAR_PEDIDO) para el caso
--      en que no alcance el stock de algún ingrediente de la receta.
--      Ejemplo de declaración (se repite dentro del procedimiento):
--
--      e_stock_insuficiente EXCEPTION;
--      PRAGMA EXCEPTION_INIT(e_stock_insuficiente, -20001);


/* =========================================================================
   2. PROCEDIMIENTO ALMACENADO: PR_PROCESAR_PEDIDO
   ========================================================================= */

CREATE OR REPLACE PROCEDURE pr_procesar_pedido (
    p_id_pedido IN pedidos.id_pedido%TYPE
)
IS
    -- Excepción personalizada del punto 1.b
    e_stock_insuficiente EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_stock_insuficiente, -20001);

    -- Cursor con parámetro: recorre cada ingrediente requerido para
    -- cada producto del pedido (loop anidado a través del JOIN)
    CURSOR c_ingredientes_pedido (p_pedido pedidos.id_pedido%TYPE) IS
        SELECT rd.id_ingrediente,
               rd.cantidad_requerida * dp.cantidad AS cantidad_total,
               ing.stock_actual,
               ing.nombre
        FROM   detalle_pedido dp
        JOIN   receta_detalle rd ON rd.id_producto = dp.id_producto
        JOIN   ingredientes ing  ON ing.id_ingrediente = rd.id_ingrediente
        WHERE  dp.id_pedido = p_pedido;

    v_existe_pedido NUMBER;
BEGIN
    -- Verificación explícita de existencia del pedido, usando
    -- NO_DATA_FOUND (excepción predefinida de Oracle)
    SELECT COUNT(*) INTO v_existe_pedido
    FROM   pedidos
    WHERE  id_pedido = p_id_pedido;

    IF v_existe_pedido = 0 THEN
        RAISE NO_DATA_FOUND;
    END IF;

    -- Recorre los ingredientes necesarios y descuenta stock
    FOR r_ing IN c_ingredientes_pedido(p_id_pedido) LOOP
        IF r_ing.stock_actual < r_ing.cantidad_total THEN
            RAISE e_stock_insuficiente;
        END IF;

        UPDATE ingredientes
        SET    stock_actual = stock_actual - r_ing.cantidad_total
        WHERE  id_ingrediente = r_ing.id_ingrediente;
    END LOOP;

    -- Marca el pedido como procesado
    UPDATE pedidos
    SET    estado = 'PROCESADO'
    WHERE  id_pedido = p_id_pedido;

    COMMIT;

    DBMS_OUTPUT.PUT_LINE('Pedido ' || p_id_pedido || ' procesado correctamente.');

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error: el pedido ' || p_id_pedido || ' no existe.');

    WHEN e_stock_insuficiente THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error: stock insuficiente para procesar el pedido ' || p_id_pedido || '.');

    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error inesperado: ' || SQLERRM);
        RAISE_APPLICATION_ERROR(-20099, 'Error al procesar el pedido: ' || SQLERRM);
END pr_procesar_pedido;
/


/* =========================================================================
   3. FUNCIÓN ALMACENADA: FN_CALCULAR_TOTAL_PEDIDO
   ========================================================================= */

CREATE OR REPLACE FUNCTION fn_calcular_total_pedido (
    p_id_pedido IN pedidos.id_pedido%TYPE
) RETURN NUMBER
IS
    v_total NUMBER(10,2) := 0;
BEGIN
    SELECT SUM(dp.cantidad * pr.precio)
    INTO   v_total
    FROM   detalle_pedido dp
    JOIN   productos pr ON pr.id_producto = dp.id_producto
    WHERE  dp.id_pedido = p_id_pedido;

    IF v_total IS NULL THEN
        RAISE NO_DATA_FOUND;
    END IF;

    -- Deja el total calculado guardado en el pedido
    UPDATE pedidos
    SET    total = v_total
    WHERE  id_pedido = p_id_pedido;
    COMMIT;

    RETURN v_total;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('Error: el pedido ' || p_id_pedido || ' no tiene detalle o no existe.');
        RETURN NULL;
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error inesperado al calcular el total: ' || SQLERRM);
        RETURN NULL;
END fn_calcular_total_pedido;
/


/* =========================================================================
   4. PACKAGE: PKG_GESTION_PEDIDOS
   (aquí se agrupa lo tuyo; luego se suma lo del compañero que hizo el
   Bloque 1 para dejar todo en un solo package)
   ========================================================================= */

CREATE OR REPLACE PACKAGE pkg_gestion_pedidos AS

    PROCEDURE pr_procesar_pedido (
        p_id_pedido IN pedidos.id_pedido%TYPE
    );

    FUNCTION fn_calcular_total_pedido (
        p_id_pedido IN pedidos.id_pedido%TYPE
    ) RETURN NUMBER;

    -- TODO: agregar aquí las firmas de los procedimientos/funciones
    -- del compañero que desarrolló el Bloque 1 (RECORD/VARRAY, cursores).

END pkg_gestion_pedidos;
/


CREATE OR REPLACE PACKAGE BODY pkg_gestion_pedidos AS

    PROCEDURE pr_procesar_pedido (
        p_id_pedido IN pedidos.id_pedido%TYPE
    )
    IS
        e_stock_insuficiente EXCEPTION;
        PRAGMA EXCEPTION_INIT(e_stock_insuficiente, -20001);

        CURSOR c_ingredientes_pedido (p_pedido pedidos.id_pedido%TYPE) IS
            SELECT rd.id_ingrediente,
                   rd.cantidad_requerida * dp.cantidad AS cantidad_total,
                   ing.stock_actual
            FROM   detalle_pedido dp
            JOIN   receta_detalle rd ON rd.id_producto = dp.id_producto
            JOIN   ingredientes ing  ON ing.id_ingrediente = rd.id_ingrediente
            WHERE  dp.id_pedido = p_pedido;

        v_existe_pedido NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_existe_pedido FROM pedidos WHERE id_pedido = p_id_pedido;
        IF v_existe_pedido = 0 THEN
            RAISE NO_DATA_FOUND;
        END IF;

        FOR r_ing IN c_ingredientes_pedido(p_id_pedido) LOOP
            IF r_ing.stock_actual < r_ing.cantidad_total THEN
                RAISE e_stock_insuficiente;
            END IF;

            UPDATE ingredientes
            SET    stock_actual = stock_actual - r_ing.cantidad_total
            WHERE  id_ingrediente = r_ing.id_ingrediente;
        END LOOP;

        UPDATE pedidos SET estado = 'PROCESADO' WHERE id_pedido = p_id_pedido;
        COMMIT;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            ROLLBACK;
            DBMS_OUTPUT.PUT_LINE('Error: el pedido ' || p_id_pedido || ' no existe.');
        WHEN e_stock_insuficiente THEN
            ROLLBACK;
            DBMS_OUTPUT.PUT_LINE('Error: stock insuficiente para el pedido ' || p_id_pedido || '.');
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE_APPLICATION_ERROR(-20099, 'Error al procesar el pedido: ' || SQLERRM);
    END pr_procesar_pedido;


    FUNCTION fn_calcular_total_pedido (
        p_id_pedido IN pedidos.id_pedido%TYPE
    ) RETURN NUMBER
    IS
        v_total NUMBER(10,2) := 0;
    BEGIN
        SELECT SUM(dp.cantidad * pr.precio)
        INTO   v_total
        FROM   detalle_pedido dp
        JOIN   productos pr ON pr.id_producto = dp.id_producto
        WHERE  dp.id_pedido = p_id_pedido;

        IF v_total IS NULL THEN
            RAISE NO_DATA_FOUND;
        END IF;

        UPDATE pedidos SET total = v_total WHERE id_pedido = p_id_pedido;
        COMMIT;

        RETURN v_total;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('Error: el pedido ' || p_id_pedido || ' no tiene detalle o no existe.');
            RETURN NULL;
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Error inesperado: ' || SQLERRM);
            RETURN NULL;
    END fn_calcular_total_pedido;

END pkg_gestion_pedidos;
/


/* =========================================================================
   5. TRIGGER: TRG_AUDITORIA_STOCK
   ========================================================================= */

CREATE OR REPLACE TRIGGER trg_auditoria_stock
AFTER UPDATE OF stock_actual ON ingredientes
FOR EACH ROW
BEGIN
    INSERT INTO auditoria_stock (
        id_ingrediente,
        stock_anterior,
        stock_nuevo,
        fecha_cambio,
        usuario_bd
    ) VALUES (
        :OLD.id_ingrediente,
        :OLD.stock_actual,
        :NEW.stock_actual,
        SYSDATE,
        USER
    );
END trg_auditoria_stock;
/


/* =========================================================================
   6. PRUEBAS RÁPIDAS (opcional, para verificar que todo funciona)
   ========================================================================= */

/*
SET SERVEROUTPUT ON;

-- Datos de ejemplo
INSERT INTO ingredientes VALUES (1, 'Harina', 100, 'kg');
INSERT INTO ingredientes VALUES (2, 'Queso', 50, 'kg');

INSERT INTO productos VALUES (1, 'Pizza', 8990);

INSERT INTO receta_detalle VALUES (1, 1, 0.3);
INSERT INTO receta_detalle VALUES (1, 2, 0.2);

INSERT INTO pedidos (id_pedido, id_cliente) VALUES (1001, 55);
INSERT INTO detalle_pedido VALUES (1001, 1, 2);
COMMIT;

-- Debe procesar correctamente y descontar stock
EXEC pkg_gestion_pedidos.pr_procesar_pedido(1001);

-- Debe calcular el total (2 pizzas x 8990)
SELECT pkg_gestion_pedidos.fn_calcular_total_pedido(1001) FROM dual;

-- Debe fallar con NO_DATA_FOUND (pedido inexistente)
EXEC pkg_gestion_pedidos.pr_procesar_pedido(9999);

-- Revisar auditoría generada por el trigger
SELECT * FROM auditoria_stock;
*/
