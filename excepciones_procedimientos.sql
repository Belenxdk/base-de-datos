
CREATE TABLE auditoria_stock (
    id_auditoria       NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_ingrediente     NUMBER,
    nombre_ingrediente VARCHAR2(50),
    stock_anterior     NUMBER,
    stock_nuevo        NUMBER,
    fecha_cambio       DATE,
    usuario_bd         VARCHAR2(50)
);



CREATE OR REPLACE PACKAGE pkg_gestion_pedidos AS

    e_stock_insuficiente EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_stock_insuficiente, -20001);
    PROCEDURE pr_procesar_pedido(p_id_pedido IN pedidos.id_pedido%TYPE);
    FUNCTION fn_calcular_total_pedido(p_id_pedido IN pedidos.id_pedido%TYPE)
        RETURN NUMBER;

END pkg_gestion_pedidos;
/
CREATE OR REPLACE PACKAGE BODY pkg_gestion_pedidos AS

    PROCEDURE pr_procesar_pedido(p_id_pedido IN pedidos.id_pedido%TYPE) IS

        v_estado              pedidos.estado%TYPE;
        v_stock_actual        ingredientes.stock_actual%TYPE;
        v_nombre_ingrediente  ingredientes.nombre%TYPE;
        v_necesario           NUMBER;
        CURSOR c_detalle IS
            SELECT id_producto, cantidad
            FROM   detalle_pedidos
            WHERE  id_pedido = p_id_pedido;
        CURSOR c_receta(p_id_producto productos.id_producto%TYPE) IS
            SELECT id_ingrediente, cantidad_requerida
            FROM   receta
            WHERE  id_producto = p_id_producto;

    BEGIN
        SELECT estado
        INTO   v_estado
        FROM   pedidos
        WHERE  id_pedido = p_id_pedido;

        FOR r_det IN c_detalle LOOP
            FOR r_rec IN c_receta(r_det.id_producto) LOOP

                v_necesario := r_rec.cantidad_requerida * r_det.cantidad;

                SELECT stock_actual, nombre
                INTO   v_stock_actual, v_nombre_ingrediente
                FROM   ingredientes
                WHERE  id_ingrediente = r_rec.id_ingrediente
                FOR UPDATE;

                IF v_stock_actual < v_necesario THEN
                    RAISE_APPLICATION_ERROR(
                        -20001,
                        'Stock insuficiente de "' || v_nombre_ingrediente ||
                        '" para procesar el pedido ' || p_id_pedido ||
                        '. Requerido: ' || v_necesario ||
                        ', disponible: ' || v_stock_actual || '.'
                    );
                END IF;

                UPDATE ingredientes
                SET    stock_actual = stock_actual - v_necesario
                WHERE  id_ingrediente = r_rec.id_ingrediente;
            END LOOP;
        END LOOP;

        UPDATE pedidos
        SET    estado = 'PROCESADO'
        WHERE  id_pedido = p_id_pedido;

        COMMIT;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            ROLLBACK;
            RAISE_APPLICATION_ERROR(-20010, 'El pedido N° ' || p_id_pedido || ' no existe.');
        WHEN e_stock_insuficiente THEN
            ROLLBACK;
            RAISE;
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END pr_procesar_pedido;


    FUNCTION fn_calcular_total_pedido(p_id_pedido IN pedidos.id_pedido%TYPE)
        RETURN NUMBER
    IS
        v_total  NUMBER := 0;
        v_existe NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_existe FROM pedidos WHERE id_pedido = p_id_pedido;

        IF v_existe = 0 THEN
            RAISE_APPLICATION_ERROR(
                -20011,
                'No se puede calcular el total: el pedido ' || p_id_pedido || ' no existe.'
            );
        END IF;

        SELECT NVL(SUM(cantidad * precio_unitario), 0)
        INTO   v_total
        FROM   detalle_pedidos
        WHERE  id_pedido = p_id_pedido;

        RETURN v_total;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN 0;
        WHEN OTHERS THEN
            RAISE;
    END fn_calcular_total_pedido;

END pkg_gestion_pedidos;
/
CREATE OR REPLACE TRIGGER trg_auditoria_stock
AFTER UPDATE OF stock_actual ON ingredientes
FOR EACH ROW
WHEN (NVL(OLD.stock_actual, -1) != NVL(NEW.stock_actual, -1))
BEGIN
    INSERT INTO auditoria_stock (
        id_ingrediente, nombre_ingrediente, stock_anterior,
        stock_nuevo, fecha_cambio, usuario_bd
    ) VALUES (
        :NEW.id_ingrediente, :NEW.nombre, :OLD.stock_actual,
        :NEW.stock_actual, SYSDATE, USER
    );
END;
/
SET SERVEROUTPUT ON;
DECLARE
    v_total NUMBER;
BEGIN
    pkg_gestion_pedidos.pr_procesar_pedido(1);
    v_total := pkg_gestion_pedidos.fn_calcular_total_pedido(1);
    DBMS_OUTPUT.PUT_LINE('Pedido 1 procesado correctamente. Total: ' || v_total);
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error inesperado: ' || SQLERRM);
END;
/
BEGIN
    pkg_gestion_pedidos.pr_procesar_pedido(999);
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error esperado (pedido inexistente): ' || SQLERRM);
END;
/
SELECT * FROM auditoria_stock ORDER BY fecha_cambio DESC;
