#version 450

in vec2 uv;

out vec4 frag_color;

uniform float i_time;
uniform vec2 i_resolution;
uniform vec2 sg_alpha;
uniform vec2 sg_mouse;

// IQs' magic
float dot2(in vec2 v) {
	return dot(v, v);
}
float dot2(in vec3 v) {
	return dot(v, v);
}
float ndot(in vec2 a, in vec2 b) {
	return a.x * b.x - a.y * b.y;
}

// CSG

vec2 smin_cubic(float a, float b, float k) {
	float h = max(k - abs(a - b), 0.0) / k;
	float m = h * h * h * 0.5;
	float s = m * k * (1.0 / 3.0);
	return (a < b) ? vec2(a - s, m) : vec2(b - s, 1.0 - m);
}

vec2 smax_cubic(float a, float b, float k) {
	float h = max(k - abs(a - b), 0.0) / k;
	float m = h * h * h * 0.5;
	float s = m * k * (1.0 / 3.0);
	return (a > b) ? vec2(a - s, m) : vec2(b - s, 1.0 - m);
}

vec4 sdf_union(vec4 a, vec4 b) {
	return (a.a < b.a) ? a : b;
}

vec4 sdf_subtraction(vec4 a, vec4 b) {
	return (-a.a > b.a) ? vec4(a.rgb, -a.a) : b;
}

vec4 sdf_intersection(vec4 a, vec4 b) {
	return (a.a > b.a) ? a : b;
}

vec4 sdf_smooth_union(vec4 a, vec4 b, float k) {
	vec2 sm = smin_cubic(a.a, b.a, k);
	vec3 col = mix(a.rgb, b.rgb, sm.y);
	return vec4(col, sm.x);
}

vec4 sdf_smooth_subtraction(vec4 a, vec4 b, float k) {
	vec2 sm = smax_cubic(-a.a, b.a, k);
	vec3 col = mix(a.rgb, b.rgb, sm.y);
	return vec4(col, sm.x);
}

vec4 sdf_smooth_intersection(vec4 a, vec4 b, float k) {
	vec2 sm = smax_cubic(a.a, b.a, k);
	vec3 col = mix(a.rgb, b.rgb, sm.y);
	return vec4(col, sm.x);
}

// Tools for GLSL 1.10
vec3 dumbround(vec3 v) {
	v += 0.5f;
	return vec3(float(int(v.x)), float(int(v.y)), float(int(v.z)));
}

vec4 render();

void main() {
	frag_color = render() - (i_time * i_resolution.x * 1e-20);
}

////---- shadergen_source ----////
float sd_box(vec3 p, vec3 b) {
vec3 q = abs(p) - b;
return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);}

float sd_hex_prism(vec3 p, vec2 h) {
const vec3 k = vec3(-0.8660254, 0.5, 0.57735);
p = abs(p);
p.xy -= 2.0 * min(dot(k.xy, p.xy), 0.0) * k.xy;
vec2 d = vec2(length(p.xy - vec2(clamp(p.x, -k.z * h.x, k.z * h.x), h.x)) * sign(p.y - h.x),
p.z - h.y);
return min(max(d.x, d.y), 0.0) + length(max(d, 0.0));}

float sd_link(vec3 p, float le, float r1, float r2) {
vec3 q = vec3(p.x, max(abs(p.y) - le, 0.0), p.z);
return length(vec2(length(q.xy) - r1, q.z)) - r2;}

float sd_torus(vec3 p, vec2 t) {
vec2 q = vec2(length(p.xz) - t.x, p.y);
return length(q) - t.y;}

float sd_capsule(vec3 p, vec3 a, vec3 b, float r) {
vec3 pa = p - a, ba = b - a;
float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
return length(pa - ba * h) - r;}

float sd_cut_sphere(vec3 p, float r, float h) {
// sampling independent computations (only depend on shape)
float w = sqrt(r * r - h * h);
// sampling dependant computations
vec2 q = vec2(length(p.xz), p.y);
float s = max((h - r) * q.x * q.x + w * w * (h + r - 2.0 * q.y), h * q.x - w * q.y);
return (s < 0.0) ? length(q) - r : (q.x < w) ? h - q.y : length(q - vec2(w, h));}

float sd_box_frame(vec3 p, vec3 b, float e) {
p = abs(p) - b;
vec3 q = abs(p + e) - e;
return min(min(length(max(vec3(p.x, q.y, q.z), 0.0)) + min(max(p.x, max(q.y, q.z)), 0.0),
length(max(vec3(q.x, p.y, q.z), 0.0)) + min(max(q.x, max(p.y, q.z)), 0.0)),
length(max(vec3(q.x, q.y, p.z), 0.0)) + min(max(q.x, max(q.y, p.z)), 0.0));}

float sd_octahedron(vec3 p, float s) {
p = abs(p);
float m = p.x + p.y + p.z - s;
vec3 q;
if (3.0 * p.x < m)
q = p.xyz;
else if (3.0 * p.y < m)
q = p.yzx;
else if (3.0 * p.z < m)
q = p.zxy;
else
return m * 0.57735027;
float k = clamp(0.5 * (q.z - q.y + s), 0.0, s);
return length(vec3(q.x, q.y - s + k, q.z - k));}

uniform vec4 sg_data[61];
float td(int offset) {return sg_data[offset / 4][offset % 4];}
vec4 sg_node64(vec3 p);vec4 sg_node62(vec3 p);vec4 sg_node60(vec3 p);vec4 sg_node58(vec3 p);vec4 sg_node56(vec3 p);vec4 sg_node54(vec3 p);vec4 sg_node52(vec3 p);vec4 sg_node50(vec3 p);vec4 sg_node51(vec3 p);vec4 sg_node47(vec3 p);vec4 sg_node48(vec3 p);vec4 sg_node43(vec3 p);vec4 sg_node44(vec3 p);vec4 sg_node40(vec3 p);vec4 sg_node41(vec3 p);vec4 sg_node33(vec3 p);vec4 sg_node34(vec3 p);vec4 sg_node30(vec3 p);vec4 sg_node31(vec3 p);vec4 sg_node26(vec3 p);vec4 sg_node27(vec3 p);vec4 sg_node23(vec3 p);vec4 sg_node24(vec3 p);vec4 sg_node17(vec3 p);vec4 sg_node18(vec3 p);vec4 sg_node14(vec3 p);vec4 sg_node15(vec3 p);vec4 sg_node9(vec3 p);vec4 sg_node10(vec3 p);vec4 sg_node5(vec3 p);vec4 sg_node6(vec3 p);vec4 sg_node65(vec3 p);vec4 sg_node63(vec3 p);vec4 sg_node61(vec3 p);vec4 sg_node59(vec3 p);vec4 sg_node57(vec3 p);vec4 sg_node55(vec3 p);vec4 sg_node53(vec3 p);vec4 sg_node36(vec3 p);vec4 sg_node35(vec3 p);vec4 sg_node37(vec3 p);vec4 sg_node38(vec3 p);vec4 sg_node45(vec3 p);vec4 sg_node46(vec3 p);vec4 sg_node49(vec3 p);vec4 sg_node39(vec3 p);vec4 sg_node42(vec3 p);vec4 sg_node19(vec3 p);vec4 sg_node20(vec3 p);vec4 sg_node21(vec3 p);vec4 sg_node28(vec3 p);vec4 sg_node29(vec3 p);vec4 sg_node32(vec3 p);vec4 sg_node22(vec3 p);vec4 sg_node25(vec3 p);vec4 sg_node11(vec3 p);vec4 sg_node12(vec3 p);vec4 sg_node13(vec3 p);vec4 sg_node16(vec3 p);vec4 sg_node7(vec3 p);vec4 sg_node8(vec3 p);vec4 sg_node64(vec3 p) {return vec4(td(46),td(47),td(48),sd_octahedron(p,td(45)));}
vec4 sg_node62(vec3 p) {return vec4(td(56),td(57),td(58),sd_capsule(p,vec3(td(49),td(50),td(51)),vec3(td(52),td(53),td(54)),td(55)));}
vec4 sg_node60(vec3 p) {return vec4(td(61),td(62),td(63),sd_torus(p,vec2(td(59),td(60))));}
vec4 sg_node58(vec3 p) {return vec4(td(66),td(67),td(68),sd_cut_sphere(p,td(64),td(65)));}
vec4 sg_node56(vec3 p) {return vec4(td(73),td(74),td(75),sd_box_frame(p,vec3(td(69),td(70),td(71)), td(72)));}
vec4 sg_node54(vec3 p) {return vec4(td(79),td(80),td(81),sd_link(p,td(76),td(77),td(78)));}
vec4 sg_node52(vec3 p) {return vec4(td(84),td(85),td(86),sd_hex_prism(p,vec2(td(82),td(83))));}
vec4 sg_node50(vec3 p) {return vec4(td(90),td(91),td(92),sd_box(p,vec3(td(87),td(88),td(89))));}
vec4 sg_node51(vec3 p) {return vec4(td(95),td(96),td(97),sd_torus(p,vec2(td(93),td(94))));}
vec4 sg_node47(vec3 p) {return vec4(td(101),td(102),td(103),sd_box(p,vec3(td(98),td(99),td(100))));}
vec4 sg_node48(vec3 p) {return vec4(td(106),td(107),td(108),sd_torus(p,vec2(td(104),td(105))));}
vec4 sg_node43(vec3 p) {return vec4(td(112),td(113),td(114),sd_box(p,vec3(td(109),td(110),td(111))));}
vec4 sg_node44(vec3 p) {return vec4(td(117),td(118),td(119),sd_torus(p,vec2(td(115),td(116))));}
vec4 sg_node40(vec3 p) {return vec4(td(123),td(124),td(125),sd_box(p,vec3(td(120),td(121),td(122))));}
vec4 sg_node41(vec3 p) {return vec4(td(128),td(129),td(130),sd_torus(p,vec2(td(126),td(127))));}
vec4 sg_node33(vec3 p) {return vec4(td(134),td(135),td(136),sd_box(p,vec3(td(131),td(132),td(133))));}
vec4 sg_node34(vec3 p) {return vec4(td(139),td(140),td(141),sd_torus(p,vec2(td(137),td(138))));}
vec4 sg_node30(vec3 p) {return vec4(td(145),td(146),td(147),sd_box(p,vec3(td(142),td(143),td(144))));}
vec4 sg_node31(vec3 p) {return vec4(td(150),td(151),td(152),sd_torus(p,vec2(td(148),td(149))));}
vec4 sg_node26(vec3 p) {return vec4(td(156),td(157),td(158),sd_box(p,vec3(td(153),td(154),td(155))));}
vec4 sg_node27(vec3 p) {return vec4(td(161),td(162),td(163),sd_torus(p,vec2(td(159),td(160))));}
vec4 sg_node23(vec3 p) {return vec4(td(167),td(168),td(169),sd_box(p,vec3(td(164),td(165),td(166))));}
vec4 sg_node24(vec3 p) {return vec4(td(172),td(173),td(174),sd_torus(p,vec2(td(170),td(171))));}
vec4 sg_node17(vec3 p) {return vec4(td(178),td(179),td(180),sd_box(p,vec3(td(175),td(176),td(177))));}
vec4 sg_node18(vec3 p) {return vec4(td(183),td(184),td(185),sd_torus(p,vec2(td(181),td(182))));}
vec4 sg_node14(vec3 p) {return vec4(td(189),td(190),td(191),sd_box(p,vec3(td(186),td(187),td(188))));}
vec4 sg_node15(vec3 p) {return vec4(td(194),td(195),td(196),sd_torus(p,vec2(td(192),td(193))));}
vec4 sg_node9(vec3 p) {return vec4(td(200),td(201),td(202),sd_box(p,vec3(td(197),td(198),td(199))));}
vec4 sg_node10(vec3 p) {return vec4(td(205),td(206),td(207),sd_torus(p,vec2(td(203),td(204))));}
vec4 sg_node5(vec3 p) {return vec4(td(211),td(212),td(213),sd_box(p,vec3(td(208),td(209),td(210))));}
vec4 sg_node6(vec3 p) {return vec4(td(216),td(217),td(218),sd_torus(p,vec2(td(214),td(215))));}
vec4 sg_node65(vec3 p) {return sdf_subtraction(sg_node63(p), sg_node64(p));}
vec4 sg_node63(vec3 p) {return sdf_smooth_union(sg_node61(p), sg_node62(p), td(219));}
vec4 sg_node61(vec3 p) {return sdf_smooth_union(sg_node59(p), sg_node60(p), td(220));}
vec4 sg_node59(vec3 p) {return sdf_intersection(sg_node57(p), sg_node58(p));}
vec4 sg_node57(vec3 p) {return sdf_smooth_union(sg_node55(p), sg_node56(p), td(221));}
vec4 sg_node55(vec3 p) {return sdf_intersection(sg_node53(p), sg_node54(p));}
vec4 sg_node53(vec3 p) {return sdf_intersection(sg_node36(p), sg_node52(p));}
vec4 sg_node36(vec3 p) {return sdf_union(sg_node35(p), sg_node37(p));}
vec4 sg_node35(vec3 p) {return sdf_smooth_union(sg_node19(p), sg_node20(p), td(222));}
vec4 sg_node37(vec3 p) {return sdf_smooth_union(sg_node38(p), sg_node45(p), td(223));}
vec4 sg_node38(vec3 p) {return sdf_smooth_union(sg_node39(p), sg_node42(p), td(224));}
vec4 sg_node45(vec3 p) {return sdf_smooth_union(sg_node46(p), sg_node49(p), td(225));}
vec4 sg_node46(vec3 p) {return sdf_smooth_union(sg_node47(p), sg_node48(p), td(226));}
vec4 sg_node49(vec3 p) {return sdf_smooth_union(sg_node50(p), sg_node51(p), td(227));}
vec4 sg_node39(vec3 p) {return sdf_smooth_union(sg_node40(p), sg_node41(p), td(228));}
vec4 sg_node42(vec3 p) {return sdf_smooth_union(sg_node43(p), sg_node44(p), td(229));}
vec4 sg_node19(vec3 p) {return sdf_smooth_union(sg_node11(p), sg_node12(p), td(230));}
vec4 sg_node20(vec3 p) {return sdf_smooth_union(sg_node21(p), sg_node28(p), td(231));}
vec4 sg_node21(vec3 p) {return sdf_smooth_union(sg_node22(p), sg_node25(p), td(232));}
vec4 sg_node28(vec3 p) {return sdf_smooth_union(sg_node29(p), sg_node32(p), td(233));}
vec4 sg_node29(vec3 p) {return sdf_smooth_union(sg_node30(p), sg_node31(p), td(234));}
vec4 sg_node32(vec3 p) {return sdf_smooth_union(sg_node33(p), sg_node34(p), td(235));}
vec4 sg_node22(vec3 p) {return sdf_smooth_union(sg_node23(p), sg_node24(p), td(236));}
vec4 sg_node25(vec3 p) {return sdf_smooth_union(sg_node26(p), sg_node27(p), td(237));}
vec4 sg_node11(vec3 p) {return sdf_smooth_union(sg_node7(p), sg_node8(p), td(238));}
vec4 sg_node12(vec3 p) {return sdf_smooth_union(sg_node13(p), sg_node16(p), td(239));}
vec4 sg_node13(vec3 p) {return sdf_smooth_union(sg_node14(p), sg_node15(p), td(240));}
vec4 sg_node16(vec3 p) {return sdf_smooth_union(sg_node17(p), sg_node18(p), td(241));}
vec4 sg_node7(vec3 p) {return sdf_smooth_union(sg_node5(p), sg_node6(p), td(242));}
vec4 sg_node8(vec3 p) {return sdf_smooth_union(sg_node9(p), sg_node10(p), td(243));}
vec4 get_dist(vec3 p) {vec4 dist=vec4(0.0,0.0,0.0,1000.0);dist = sdf_union(sg_node65(p), dist);return dist;}

#define MAX_STEPS int(sg_data[9][2])
#define MAX_DIST sg_data[9][3]
#define SURF_DIST sg_data[10][0]

#define shininess sg_data[10][1]

vec4 raymarch(vec3 ro, vec3 rd) {
	float dO = 0.0;
	vec3 col = vec3(0.0);
	for (int i = 0; i < MAX_STEPS; i++) {
		vec3 p = ro + rd * dO;
		vec4 dS = get_dist(p);
		dO += dS.a;
		if (abs(dS.a) < SURF_DIST) col = dS.rgb;
		if (dO > MAX_DIST || abs(dS.a) < SURF_DIST) break;
	}
	return vec4(col, dO);
}

vec3 get_normal(vec3 p) {
	const float h = 0.001;
	const vec2 k = vec2(1.0, -1.0);

	return normalize(k.xyy * get_dist(p + k.xyy * h).a + k.yyx * get_dist(p + k.yyx * h).a +
	                 k.yxy * get_dist(p + k.yxy * h).a + k.xxx * get_dist(p + k.xxx * h).a);
}

vec3 get_ray_direction(vec2 nuv, vec3 p, vec3 l, float z) {
	vec3 f = normalize(l - p);
	vec3 r = normalize(cross(vec3(0.0, 1.0, 0.0), f));
	vec3 u = cross(f, r);
	vec3 c = f * z;
	vec3 i = c + nuv.x * r + nuv.y * u;
	vec3 d = normalize(i);
	return d;
}

// https://iquilezles.org/articles/nvscene2008/rwwtt.pdf
float calc_ao(vec3 pos, vec3 nor) {
	float occ = 0.0;
	float sca = 1.0;
	for (int i = 0; i < 5; i++) {
		float h = 0.01 + 0.12 * float(i) / 4.0;
		float d = get_dist(pos + h * nor).a;
		occ += (h - d) * sca;
		sca *= 0.95;
		if (occ > 0.35) break;
	}
	return clamp(1.0 - 3.0 * occ, 0.0, 1.0) * (0.5 + 0.5 * nor.y);
}

mat3 set_camera(in vec3 ro, in vec3 ta, float cr) {
	vec3 cw = normalize(ta - ro);
	vec3 cp = vec3(sin(cr), cos(cr), 0.0);
	vec3 cu = normalize(cross(cw, cp));
	vec3 cv = (cross(cu, cw));
	return mat3(cu, cv, cw);
}

vec3 spherical_harmonics(vec3 n) {
	const float C1 = 0.429043;
	const float C2 = 0.511664;
	const float C3 = 0.743125;
	const float C4 = 0.886227;
	const float C5 = 0.247708;

	const vec3 L00 = vec3(sg_data[2][2], sg_data[2][3], sg_data[3][0]);
	const vec3 L1m1 = vec3(sg_data[3][1], sg_data[3][2], sg_data[3][3]);
	const vec3 L10 = vec3(sg_data[4][0], sg_data[4][1], sg_data[4][2]);
	const vec3 L11 = vec3(sg_data[4][3], sg_data[5][0], sg_data[5][1]);
	const vec3 L2m2 = vec3(sg_data[5][2], sg_data[5][3], sg_data[6][0]);
	const vec3 L2m1 = vec3(sg_data[6][1], sg_data[6][2], sg_data[6][3]);
	const vec3 L20 = vec3(sg_data[7][0], sg_data[7][1], sg_data[7][2]);
	const vec3 L21 = vec3(sg_data[7][3], sg_data[8][0], sg_data[8][1]);
	const vec3 L22 = vec3(sg_data[8][2], sg_data[8][3], sg_data[9][0]);

	return (C1 * L22 * (n.x * n.x - n.y * n.y) + C3 * L20 * n.z * n.z + C4 * L00 - C5 * L20 +
	        2.0 * C1 * L2m2 * n.x * n.y + 2.0 * C1 * L21 * n.x * n.z + 2.0 * C1 * L2m1 * n.y * n.z +
	        2.0 * C2 * L11 * n.x + 2.0 * C2 * L1m1 * n.y + 2.0 * C2 * L10 * n.z) *
	       sg_data[9][1];
}

vec4 render() {
	vec2 frag_coord = uv * i_resolution;

	// camera
	vec3 ta = vec3(sg_data[1][0], sg_data[1][1], sg_data[1][2]);
	vec3 ro = vec3(sg_data[0][1], sg_data[0][2], sg_data[0][3]);
	mat3 ca = set_camera(ro, ta, 0.0);

	vec3 tot = vec3(0.0);
	int hits = 0;
	for (int m = 0; m < 2; m++)
		for (int n = 0; n < 2; n++) {
			// pixel coordinates
			vec2 o = vec2(float(m), float(n)) / 2.0f - 0.5;
			vec2 frag_pos = (2.0 * (frag_coord + o) - i_resolution.xy) / i_resolution.y;
			vec2 m = (2.0 * (sg_mouse + o) - i_resolution.xy) / i_resolution.y;

			// focal length
			const float fl = sg_data[0][0];

			// ray direction
			vec3 rd = ca * normalize(vec3(frag_pos, fl));

			// render
			vec4 rm = raymarch(ro, rd);
			vec3 ambient = vec3(0.05);
			vec3 specular = vec3(1.0);
			vec3 col = vec3(sg_data[1][3], sg_data[2][0], sg_data[2][1]);

			vec3 l_dir = normalize(vec3(sg_data[10][2], sg_data[10][3], sg_data[11][0]));

			if (rm.a < MAX_DIST) {
				vec3 p = ro + rd * rm.a;
				vec3 n = get_normal(p);
				float occ = calc_ao(p, n);

				float intensity = max(dot(n, l_dir), 0.0);
				vec3 spec = vec3(0.0);

				if (intensity > 0.0) {
					vec3 h = normalize(l_dir - rd);
					float int_spec = max(dot(h, n), 0.0);
					spec = specular * pow(int_spec, shininess);
				}
				rm.rgb += spherical_harmonics(n);
				col = max(intensity * rm.rgb + spec, ambient * rm.rgb) * occ;
				hits++;
				float hl = (0.05 - clamp(length(frag_pos - m), 0.0, 0.05)) / 0.05;
				col.r += hl;
				col.gb = mix(col.gb, vec2(0.0), hl);
			}

			// gamma
			col = pow(col, vec3(0.4545));

			tot += col;
		}
	tot /= 4.0f;
	float alpha = hits > 0 ? sg_alpha.y : sg_alpha.x;
	return vec4(tot, alpha);
}
