declare
   type r_detalle_pedido is record (
         id_producto     number,
         nombre_producto   varchar2(80),
         cantidad        number,
         precio_unitario number,
         subtotal        number
   );
   v_linea r_detalle_pedido;
begin
   null;
end;
/