// ESP32-S3 + OV3660 猫咪看护摄像头参数化外壳
// 使用方法：
// 1. 安装 OpenSCAD
// 2. 打开本文件
// 3. 修改下面的参数
// 4. 修改 preview_part 选择要导出的零件
// 5. F6 渲染后导出 STL

$fn = 48;

// 选择导出的零件："body" 主壳体，"lid" 底盖，"servo_base" 舵机底座，"all" 总览
preview_part = "all";

// PCB 参数
pcb_w = 70;
pcb_d = 50;
pcb_thickness = 1.6;
pcb_clearance = 3;
pcb_mount_hole_d = 2.4;
pcb_mount_offset = 5;

// 外壳参数
wall = 2;
inner_h = 24;
corner_r = 5;
top_vent_count = 5;
side_vent_count = 4;

// 摄像头开孔
camera_hole_d = 14;
camera_center_x = 0;
camera_center_z = 18;

// USB-C 后部开孔
usb_w = 12;
usb_h = 7;
usb_center_x = 0;
usb_center_z = 9;

// 螺丝柱
post_d = 6;
post_h = 8;
post_hole_d = 2.0;

// 底盖
lid_thickness = 2;
lid_lip_h = 3;
lid_lip_clearance = 0.35;

// 舵机底座，默认按 SG90/MG90S 尺寸留空间
servo_body_w = 24;
servo_body_d = 13;
servo_body_h = 24;
servo_base_w = 62;
servo_base_d = 48;
servo_base_h = 16;
servo_shaft_d = 7;

outer_w = pcb_w + pcb_clearance * 2 + wall * 2;
outer_d = pcb_d + pcb_clearance * 2 + wall * 2;
outer_h = inner_h + wall + lid_thickness;

module rounded_box(size, r) {
    hull() {
        for (x = [-size[0] / 2 + r, size[0] / 2 - r])
            for (y = [-size[1] / 2 + r, size[1] / 2 - r])
                translate([x, y, 0])
                    cylinder(h = size[2], r = r);
    }
}

module screw_post(x, y, h) {
    translate([x, y, 0])
        difference() {
            cylinder(h = h, d = post_d);
            translate([0, 0, -0.1])
                cylinder(h = h + 0.2, d = post_hole_d);
        }
}

module pcb_mount_posts() {
    x = pcb_w / 2 - pcb_mount_offset;
    y = pcb_d / 2 - pcb_mount_offset;
    screw_post(-x, -y, post_h);
    screw_post(x, -y, post_h);
    screw_post(-x, y, post_h);
    screw_post(x, y, post_h);
}

module top_vents() {
    vent_w = 5;
    vent_d = 24;
    spacing = 9;
    for (i = [-(top_vent_count - 1) / 2 : 1 : (top_vent_count - 1) / 2]) {
        translate([i * spacing, 0, outer_h - wall - 0.1])
            rounded_box([vent_w, vent_d, wall + 0.3], 1.8);
    }
}

module side_vents(sign_y) {
    vent_w = 16;
    vent_h = 3;
    spacing = 7;
    for (i = [0 : side_vent_count - 1]) {
        translate([-(side_vent_count - 1) * spacing / 2 + i * spacing, sign_y * (outer_d / 2 - wall / 2), 13])
            cube([vent_h, wall + 0.4, vent_w], center = true);
    }
}

module body_shell() {
    difference() {
        rounded_box([outer_w, outer_d, outer_h], corner_r);

        translate([0, 0, lid_thickness])
            rounded_box([outer_w - wall * 2, outer_d - wall * 2, inner_h + 0.2], max(1, corner_r - wall));

        // 底部开口
        translate([0, 0, -0.2])
            rounded_box([outer_w - wall * 2, outer_d - wall * 2, lid_thickness + 0.5], max(1, corner_r - wall));

        // 摄像头前孔，前方为 -Y
        translate([camera_center_x, -outer_d / 2 - 0.1, camera_center_z])
            rotate([90, 0, 0])
                cylinder(h = wall + 0.4, d = camera_hole_d);

        // USB-C 后孔，后方为 +Y
        translate([usb_center_x, outer_d / 2 - wall - 0.2, usb_center_z])
            cube([usb_w, wall + 0.5, usb_h], center = true);

        top_vents();
        side_vents(1);
        side_vents(-1);
    }
}

module body() {
    union() {
        body_shell();
        translate([0, 0, lid_thickness])
            pcb_mount_posts();
    }
}

module lid() {
    difference() {
        union() {
            rounded_box([outer_w, outer_d, lid_thickness], corner_r);
            translate([0, 0, lid_thickness])
                rounded_box([outer_w - wall * 2 - lid_lip_clearance, outer_d - wall * 2 - lid_lip_clearance, lid_lip_h], max(1, corner_r - wall));
        }

        x = pcb_w / 2 - pcb_mount_offset;
        y = pcb_d / 2 - pcb_mount_offset;
        for (px = [-x, x])
            for (py = [-y, y])
                translate([px, py, -0.1])
                    cylinder(h = lid_thickness + lid_lip_h + 0.4, d = pcb_mount_hole_d);
    }
}

module servo_base() {
    difference() {
        rounded_box([servo_base_w, servo_base_d, servo_base_h], 5);

        translate([0, 0, servo_base_h - servo_body_h / 2])
            cube([servo_body_w + 1, servo_body_d + 1, servo_body_h + 1], center = true);

        translate([0, 0, -0.1])
            cylinder(h = servo_base_h + 0.2, d = servo_shaft_d);

        // 底部减重孔
        translate([0, 0, 2])
            rounded_box([servo_base_w - 14, servo_base_d - 14, servo_base_h], 3);
    }
}

if (preview_part == "body") {
    body();
} else if (preview_part == "lid") {
    lid();
} else if (preview_part == "servo_base") {
    servo_base();
} else {
    translate([0, 0, 0]) body();
    translate([outer_w + 12, 0, 0]) lid();
    translate([-(outer_w + 12), 0, 0]) servo_base();
}

