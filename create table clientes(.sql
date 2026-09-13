create table clientes(
    id_cliente number primary key,
    nombre varchar2(50),
    apellido varchar2(50),
    direccion varchar2(100),
    telefono varchar2(20), 
    correo  varchar2(100)
);

create table productos(
    id_producto number primary key,
    nombre varchar2(50),
    categoria varchar2(50),
    precio number,
    stock number
);

create table ingredientes(
    id_ingrediente number primary key,
    nombre varchar2(50),
    stock_actual number,
    stock_minimo number,
    unidad_medida varchar2(20)
);

create table receta(
    id_producto number references productos(id_producto),
    id_ingrediente number references ingredientes(id_ingrediente),
    cantidad_requerida number,
    constraint pk_receta primary key(id_producto, id_ingrediente)
);

create table metodo_pago (
    id_metodo number primary key,
    nombre_metodo varchar2(50) 
);

CREATE TABLE pedidos (
    id_pedido       number PRIMARY KEY,
    id_cliente      NUMBER REFERENCES clientes(id_cliente),
    id_metodo       NUMBER REFERENCES metodo_pago(id_metodo),
    fecha_pedido    DATE,
    fecha_entrega   date,
    estado          varchar2(50)
);  

create table detalle_pedidos(
    id_pedido NUMBER REFERENCES pedidos (id_pedido),
    id_producto  NUMBER REFERENCES productos(id_producto),
    cantidad NUMBER,
    precio_unitario NUMBER,
    constraint pk_detalle_pedidos PRIMARY KEY (id_pedido, id_producto)
);


INSERT INTO clientes VALUES (1, 'Belén', 'Muñoz', 'Camino Real 123, Melipilla', '+56912345678', 'bethlehem@gmail.com');
INSERT INTO clientes VALUES (2, 'Camila', 'Rojas', 'Los Aromos 456, Melipilla', '+56987654321', 'camila.rojas@gmail.com');
INSERT INTO clientes VALUES (3, 'Javiera', 'Soto', 'Av. Ortúzar 789, Melipilla', '+56911223344', 'javiera.soto@gmail.com');

INSERT INTO productos VALUES (1,  'Torta de Chocolate',           'Tortas',     25000, 10);
INSERT INTO productos VALUES (2,  'Cheesecake Frutos Rojos',      'Tortas',     22000, 8);
INSERT INTO productos VALUES (3,  'Torta Especial Cumpleaños',    'Tortas',     30000, 6);
INSERT INTO productos VALUES (4,  'Caja de Macarons',             'Individual', 12000, 20);
INSERT INTO productos VALUES (5,  'Cupcakes Surtidos (6 un.)',    'Individual', 9000,  25);
INSERT INTO productos VALUES (6,  'Brownies Artesanales (4 un.)', 'Individual', 7500,  30);
INSERT INTO productos VALUES (7,  'Torta Sin Azúcar de Naranja',  'Sin Azúcar', 27000, 5);
INSERT INTO productos VALUES (8,  'Cheesecake Sin Azúcar',        'Sin Azúcar', 24000, 5);
INSERT INTO productos VALUES (9,  'Galletas Sin Azúcar (8 un.)',  'Sin Azúcar', 6000,  15);
INSERT INTO productos VALUES (10, 'Alfajores (caja 6 un.)',       'Individual', 5000,  40);
INSERT INTO productos VALUES (11, 'Mini Donas (caja 6 un.)',      'Individual', 6000,  35);

INSERT INTO ingredientes VALUES (1,  'Harina',         50,  10, 'kg');
INSERT INTO ingredientes VALUES (2,  'Azúcar',         40,  10, 'kg');
INSERT INTO ingredientes VALUES (3,  'Huevos',         200, 50, 'unidad');
INSERT INTO ingredientes VALUES (4,  'Mantequilla',    30,  8,  'kg');
INSERT INTO ingredientes VALUES (5,  'Chocolate',      25,  5,  'kg');
INSERT INTO ingredientes VALUES (6,  'Crema de leche', 20,  5,  'lt');
INSERT INTO ingredientes VALUES (7,  'Frutos rojos',   15,  3,  'kg');
INSERT INTO ingredientes VALUES (8,  'Dulce de leche', 18,  4,  'kg');
INSERT INTO ingredientes VALUES (9,  'Naranja',        10,  3,  'kg');
INSERT INTO ingredientes VALUES (10, 'Edulcorante',    8,   2,  'kg');

INSERT INTO metodo_pago VALUES (1, 'Efectivo');
INSERT INTO metodo_pago VALUES (2, 'Transferencia');
INSERT INTO metodo_pago VALUES (3, 'Tarjeta de Débito');
INSERT INTO metodo_pago VALUES (4, 'Tarjeta de Crédito');


-- Torta de Chocolate
INSERT INTO receta VALUES (1, 1, 2);
INSERT INTO receta VALUES (1, 2, 1);
INSERT INTO receta VALUES (1, 3, 4);
INSERT INTO receta VALUES (1, 4, 0.5);
INSERT INTO receta VALUES (1, 5, 1);
-- Cheesecake Frutos Rojos
INSERT INTO receta VALUES (2, 1, 1);
INSERT INTO receta VALUES (2, 3, 3);
INSERT INTO receta VALUES (2, 6, 0.5);
INSERT INTO receta VALUES (2, 7, 0.5);
-- Torta Especial Cumpleaños
INSERT INTO receta VALUES (3, 1, 2);
INSERT INTO receta VALUES (3, 2, 1.5);
INSERT INTO receta VALUES (3, 3, 5);
INSERT INTO receta VALUES (3, 4, 0.7);
INSERT INTO receta VALUES (3, 5, 0.5);
-- Caja de Macarons
INSERT INTO receta VALUES (4, 1, 0.3);
INSERT INTO receta VALUES (4, 2, 0.5);
INSERT INTO receta VALUES (4, 3, 2);
-- Cupcakes Surtidos
INSERT INTO receta VALUES (5, 1, 0.6);
INSERT INTO receta VALUES (5, 2, 0.4);
INSERT INTO receta VALUES (5, 3, 3);
INSERT INTO receta VALUES (5, 4, 0.2);
-- Brownies Artesanales
INSERT INTO receta VALUES (6, 1, 0.4);
INSERT INTO receta VALUES (6, 3, 2);
INSERT INTO receta VALUES (6, 4, 0.3);
INSERT INTO receta VALUES (6, 5, 0.6);
-- Torta Sin Azúcar de Naranja
INSERT INTO receta VALUES (7, 1, 1.5);
INSERT INTO receta VALUES (7, 3, 4);
INSERT INTO receta VALUES (7, 9, 1);
INSERT INTO receta VALUES (7, 10, 0.5);
-- Cheesecake Sin Azúcar
INSERT INTO receta VALUES (8, 1, 1);
INSERT INTO receta VALUES (8, 3, 3);
INSERT INTO receta VALUES (8, 6, 0.5);
INSERT INTO receta VALUES (8, 10, 0.4);
-- Galletas Sin Azúcar
INSERT INTO receta VALUES (9, 1, 0.5);
INSERT INTO receta VALUES (9, 4, 0.2);
INSERT INTO receta VALUES (9, 10, 0.3);
-- Alfajores
INSERT INTO receta VALUES (10, 1, 0.4);
INSERT INTO receta VALUES (10, 4, 0.15);
INSERT INTO receta VALUES (10, 8, 0.3);
-- Mini Donas
INSERT INTO receta VALUES (11, 1, 0.5);
INSERT INTO receta VALUES (11, 2, 0.2);
INSERT INTO receta VALUES (11, 3, 2);
INSERT INTO receta VALUES (11, 4, 0.2);

INSERT INTO pedidos VALUES (1, 1, 2, DATE '2026-09-05', DATE '2026-09-14', 'PENDIENTE');
INSERT INTO pedidos VALUES (2, 2, 1, DATE '2026-09-06', DATE '2026-09-13', 'PENDIENTE');
INSERT INTO pedidos VALUES (3, 3, 3, DATE '2026-09-01', DATE '2026-09-03', 'ENTREGADO');

INSERT INTO detalle_pedidos VALUES (1, 1, 1, 25000);
INSERT INTO detalle_pedidos VALUES (1, 6, 2, 7500);
INSERT INTO detalle_pedidos VALUES (2, 10, 3, 5000);
INSERT INTO detalle_pedidos VALUES (2, 5, 1, 9000);
INSERT INTO detalle_pedidos VALUES (3, 2, 1, 22000);

COMMIT;