// Input - units are in m

// SetFactory("OpenCASCADE");

// DIMENSION CONTROL -----------------------------------------------------------------------------
le_radius = 0.1;
chord_length = 1.0;
base_hw = le_radius *3;
base_front = le_radius *2;

basetop_thickness = 0.1;
basetop_n_elements = 4;

basebeam_thickness = 0.3;
basebeam_n_elements = 12;

basebot_thickness = 0.1;
basebot_n_elements = 4;

blade_height = 1.5;
blade_n_elements = 40;

blade_twist_angle = 40; //degrees

// MESH CONTROL -----------------------------------------------------------------------------
Mesh.Algorithm = 8;
Mesh.FlexibleTransfinite = 1.0;
Mesh.QuasiTransfinite = 1.0;

lc = 0.02;

// PHYSICAL POINTS -----------------------------------------------------------------------------

// Airfoil points
Point(1) = {0, 0, 0, lc};
Point(2) = {0, le_radius, 0, lc};
Point(3) = {0,-le_radius, 0, lc};

Point(4) = {chord_length/2, le_radius/3, 0, lc};
Point(5) = {chord_length/2, -4*le_radius/5, 0, lc};
Point(6) = {chord_length, -3*le_radius/2, 0, lc};
Point(61) = {chord_length, -1.2*le_radius, 0, lc};

Point(7) = {chord_length/4, 0.8*le_radius, 0, lc};
Point(8) = {chord_length/4, -0.8*le_radius, 0, lc};

Point(9) = {3*chord_length/4, -le_radius/4, 0, 0.7*lc};
Point(10) = {3*chord_length/4, -0.9*le_radius, 0, lc};

Point(11) = {-base_front, -base_hw, 0, lc};
Point(12) = {-base_front, base_hw, 0, lc};
Point(13) = {chord_length, base_hw, 0, lc};
Point(14) = {chord_length, -base_hw, 0, lc};

Point(21) = {0, base_hw, 0, lc};
Point(31) = {0, -base_hw, 0, lc};


// PHYSICAL CURVES -----------------------------------------------------------------------------

// airfoil
Circle(1) = {2, 1, 3};
Line(27) =  {2,7};
Line(23) = {2,3};
Line(78) = {7,8};
Line(45) = {4,5};
Line(910) = {9,10};
Line(74) =  {7,4}; 
Line(49) =  {4,9}; 
Line(961) =  {9,61};
Line(616) =  {61,6}; 
Line(106) = {10,6};
Line(38) =  {3,8};
Line(85) =  {8,5};
Line(510) = {5,10}; 

// base
Line(2113) = {21,13};
Line(221) = {2,21};
Line(6113) = {61,13};

Line(1431) = {14,31};
Line(614) = {6,14};
Line(313) = {31,3};

Line(1112) = {11,12};
Line(1221) = {12,21};
Line(3111) = {31,11};

// SURFACES -----------------------------------------------------------------------------

// airfoil
id_airfoil_le = 1;
Line Loop(id_airfoil_le) = {-1,23};
Plane Surface(id_airfoil_le) = {id_airfoil_le};
Recombine Surface(id_airfoil_le);

id_airfoil_beam1 = 23;
Line Loop(id_airfoil_beam1) = {74,45,-85,-78};
Plane Surface(id_airfoil_beam1) = {id_airfoil_beam1};
Recombine Surface(id_airfoil_beam1);

id_airfoil_beam2 = 13;
Line Loop(id_airfoil_beam2) = {27,78,-38,-23};
Plane Surface(id_airfoil_beam2) = {id_airfoil_beam2};
Recombine Surface(id_airfoil_beam2);

id_airfoil_beam3 = 44;
Line Loop(id_airfoil_beam3) = {49,910,-510,-45};
Plane Surface(id_airfoil_beam3) = {id_airfoil_beam3};
Recombine Surface(id_airfoil_beam3);

id_airfoil_te = 51;
Line Loop(id_airfoil_te) = {961,616,-106,-910};
Plane Surface(id_airfoil_te) = {id_airfoil_te};
Recombine Surface(id_airfoil_te);

// base
base_t1 = 6;
Line Loop(base_t1) = {221,2113,-6113,-961,-49,-74,-27};
Plane Surface(base_t1) = {base_t1};
Recombine Surface(base_t1);

base_b1 = 8;
Line Loop(base_b1) = {313,38,85,510,106,614,1431};
Plane Surface(base_b1) = {base_b1};
Recombine Surface(base_b1);

base_le = 10;
Line Loop(base_le) = {1112,1221,-221,1,-313,3111};
Plane Surface(base_le) = {base_le};
Recombine Surface(base_le);

// EXTRUDED OUT TO DESIRABLE THICKNESS

DefineConstant[ angle = {blade_twist_angle, Min 0, Max 120, Step 1,
                         Name "Parameters/Twisting angle"} ];

h = blade_height;

// translate, rotation, center of rotation {0,0,h}, {0,0,h}, {0,chord_length/3,chord_length/3}
blade[] =  Extrude { {0,0,h}, {0,0,h} , {0,0.15,1.0} , angle * Pi / 180} 
// blade[] =  Extrude {0,0,h} 
{Surface{id_airfoil_beam1,id_airfoil_beam2,id_airfoil_beam3,
id_airfoil_le,id_airfoil_te}; Layers{ {blade_n_elements}, {1}}; Recombine;};

base_top[] =  Extrude {0, 0, -basetop_thickness} 
{Surface{id_airfoil_beam1,id_airfoil_beam2,id_airfoil_beam3,
id_airfoil_le,id_airfoil_te,
base_t1,base_b1,base_le}; Layers{ {basetop_n_elements}, {1}}; Recombine;};

base_mid[] =  Extrude {0, 0, -(basebeam_thickness+basetop_thickness)} 
{Surface{id_airfoil_beam1}; Layers{ {basetop_n_elements,basebeam_n_elements},
 {basetop_thickness/(basebeam_thickness+basetop_thickness),1}}; Recombine;};

//base_bottom[] =  Extrude {0, 0, -(basebeam_thickness+basetop_thickness+basebot_thickness)} 
//{Surface{id_airfoil_beam1,id_airfoil_beam2,id_airfoil_beam3};
// Layers{ {basetop_n_elements,basebeam_n_elements,basebot_n_elements},
// {basetop_thickness/(basebeam_thickness+basetop_thickness+basebot_thickness),
// (basetop_thickness+basebeam_thickness)/(basebeam_thickness+basetop_thickness+basebot_thickness),1}}; Recombine;};

// MESH -----------------------------------------------------------------------------

Physical Volume("core") = {1:14};

Mesh 3;
Coherence Mesh;  // Remove duplicate entities

Save "core.msh";

