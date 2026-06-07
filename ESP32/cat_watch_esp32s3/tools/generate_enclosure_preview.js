const fs = require('fs');
const path = require('path');

const outDir = path.join(__dirname, '..', 'hardware', 'enclosure_preview');
fs.mkdirSync(outDir, { recursive: true });

const mm = 1;

const cfg = {
  body: { w: 82, d: 62, h: 30 },
  wall: 2,
  camera: { d: 14, z: 19 },
  usb: { w: 12, h: 7, z: 10 },
  lid: { w: 82, d: 62, h: 2 },
  servo: { w: 62, d: 48, h: 16 },
};

function box(name, x1, y1, z1, x2, y2, z2) {
  const v = [
    [x1, y1, z1], [x2, y1, z1], [x2, y2, z1], [x1, y2, z1],
    [x1, y1, z2], [x2, y1, z2], [x2, y2, z2], [x1, y2, z2],
  ];
  const f = [
    [1, 2, 3, 4], [5, 8, 7, 6], [1, 5, 6, 2],
    [2, 6, 7, 3], [3, 7, 8, 4], [4, 8, 5, 1],
  ];
  return { name, vertices: v, faces: f };
}

function cyl(name, radius, height, z, segments = 48) {
  const vertices = [];
  for (let i = 0; i < segments; i++) {
    const a = (Math.PI * 2 * i) / segments;
    vertices.push([Math.cos(a) * radius, Math.sin(a) * radius, z]);
  }
  for (let i = 0; i < segments; i++) {
    const a = (Math.PI * 2 * i) / segments;
    vertices.push([Math.cos(a) * radius, Math.sin(a) * radius, z + height]);
  }
  const faces = [];
  for (let i = 0; i < segments; i++) {
    const j = (i + 1) % segments;
    faces.push([i + 1, j + 1, j + 1 + segments, i + 1 + segments]);
  }
  faces.push([...Array(segments).keys()].map(i => segments - i));
  faces.push([...Array(segments).keys()].map(i => i + 1 + segments));
  return { name, vertices, faces };
}

function transform(part, tx, ty, tz, rx = 0, ry = 0, rz = 0) {
  const sx = Math.sin(rx), cx = Math.cos(rx);
  const sy = Math.sin(ry), cy = Math.cos(ry);
  const sz = Math.sin(rz), cz = Math.cos(rz);
  const vertices = part.vertices.map(([x, y, z]) => {
    let y1 = y * cx - z * sx;
    let z1 = y * sx + z * cx;
    let x1 = x;
    let x2 = x1 * cy + z1 * sy;
    let z2 = -x1 * sy + z1 * cy;
    let y2 = y1;
    let x3 = x2 * cz - y2 * sz;
    let y3 = x2 * sz + y2 * cz;
    return [x3 + tx, y3 + ty, z2 + tz];
  });
  return { ...part, vertices };
}

function merge(parts) {
  const vertices = [];
  const faces = [];
  const groups = [];
  let offset = 0;
  for (const part of parts) {
    groups.push({ name: part.name, start: faces.length, count: part.faces.length });
    vertices.push(...part.vertices);
    faces.push(...part.faces.map(face => face.map(i => i + offset)));
    offset += part.vertices.length;
  }
  return { vertices, faces, groups };
}

function writeObj(model, file) {
  let obj = '# ESP32-S3 OV3660 cat watch enclosure preview\n';
  for (const v of model.vertices) obj += `v ${v[0].toFixed(3)} ${v[1].toFixed(3)} ${v[2].toFixed(3)}\n`;
  for (const face of model.faces) obj += `f ${face.join(' ')}\n`;
  fs.writeFileSync(file, obj, 'utf8');
}

function triNormal(a, b, c) {
  const ux = b[0] - a[0], uy = b[1] - a[1], uz = b[2] - a[2];
  const vx = c[0] - a[0], vy = c[1] - a[1], vz = c[2] - a[2];
  const nx = uy * vz - uz * vy;
  const ny = uz * vx - ux * vz;
  const nz = ux * vy - uy * vx;
  const len = Math.hypot(nx, ny, nz) || 1;
  return [nx / len, ny / len, nz / len];
}

function triangulate(face) {
  const tris = [];
  for (let i = 1; i < face.length - 1; i++) tris.push([face[0], face[i], face[i + 1]]);
  return tris;
}

function writeStl(model, file) {
  let stl = 'solid cat_watch_enclosure\n';
  for (const face of model.faces) {
    for (const tri of triangulate(face)) {
      const a = model.vertices[tri[0] - 1], b = model.vertices[tri[1] - 1], c = model.vertices[tri[2] - 1];
      const n = triNormal(a, b, c);
      stl += ` facet normal ${n[0]} ${n[1]} ${n[2]}\n  outer loop\n`;
      for (const v of [a, b, c]) stl += `   vertex ${v[0]} ${v[1]} ${v[2]}\n`;
      stl += '  endloop\n endfacet\n';
    }
  }
  stl += 'endsolid cat_watch_enclosure\n';
  fs.writeFileSync(file, stl, 'utf8');
}

const parts = [];

// 主壳体用半透明外轮廓表示，前方为 -Y
parts.push(box('主壳体外形', -cfg.body.w / 2, -cfg.body.d / 2, 18, cfg.body.w / 2, cfg.body.d / 2, 18 + cfg.body.h));
parts.push(box('内部空腔示意', -34, -24, 20, 34, 24, 43));
parts.push(transform(cyl('摄像头开孔示意', cfg.camera.d / 2, 3, 0), 0, -cfg.body.d / 2 - 1.5, 18 + cfg.camera.z, Math.PI / 2, 0, 0));
parts.push(box('USB-C开孔示意', -cfg.usb.w / 2, cfg.body.d / 2 - 2, 18 + cfg.usb.z - cfg.usb.h / 2, cfg.usb.w / 2, cfg.body.d / 2 + 2, 18 + cfg.usb.z + cfg.usb.h / 2));

// 顶部散热孔示意
for (let i = -2; i <= 2; i++) {
  parts.push(box('顶部散热孔示意', i * 9 - 2.5, -12, 18 + cfg.body.h - 1, i * 9 + 2.5, 12, 18 + cfg.body.h + 1));
}

// PCB
parts.push(box('PCB示意', -35, -25, 22, 35, 25, 23.6));

// 底盖和舵机底座
parts.push(box('底盖', -cfg.lid.w / 2, -cfg.lid.d / 2, 12, cfg.lid.w / 2, cfg.lid.d / 2, 14));
parts.push(box('舵机底座', -cfg.servo.w / 2, -cfg.servo.d / 2, -8, cfg.servo.w / 2, cfg.servo.d / 2, 8));
parts.push(box('舵机本体空间', -12, -6.5, -4, 12, 6.5, 18));
parts.push(cyl('舵机输出轴', 4, 8, 8));

const model = merge(parts);
writeObj(model, path.join(outDir, 'cat_watch_enclosure_preview.obj'));
writeStl(model, path.join(outDir, 'cat_watch_enclosure_preview.stl'));

const html = `<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>猫咪看护外壳 3D 预览</title>
  <style>
    body { margin: 0; font-family: Arial, "Microsoft YaHei", sans-serif; background: #eef2f6; color: #17202a; }
    #app { display: grid; grid-template-columns: 1fr 300px; min-height: 100vh; }
    canvas { display: block; width: 100%; height: 100vh; background: #dfe7ef; }
    aside { padding: 18px; background: #fff; border-left: 1px solid #cbd5df; }
    h1 { font-size: 20px; margin: 0 0 12px; }
    p, li { font-size: 14px; line-height: 1.6; }
    .tag { display:inline-block; padding: 3px 8px; border-radius: 5px; background:#e8f5f2; color:#0f766e; margin: 4px 4px 4px 0; }
    @media (max-width: 760px) { #app { grid-template-columns: 1fr; } canvas { height: 68vh; } aside { border-left: 0; border-top: 1px solid #cbd5df; } }
  </style>
</head>
<body>
  <div id="app">
    <canvas id="view"></canvas>
    <aside>
      <h1>猫咪看护外壳预览</h1>
      <p>鼠标左键拖动旋转，滚轮缩放。手机上用手指拖动旋转。</p>
      <div>
        <span class="tag">主壳体</span>
        <span class="tag">摄像头孔</span>
        <span class="tag">USB-C孔</span>
        <span class="tag">底盖</span>
        <span class="tag">舵机底座</span>
      </div>
      <p>这是结构示意模型，用于先看外观和空间关系。真正打印建议使用 <code>hardware/case_parametric.scad</code> 导出 STL。</p>
      <ul>
        <li>前方是摄像头开孔。</li>
        <li>后方是 USB-C 开孔。</li>
        <li>顶部是散热孔。</li>
        <li>底部预留舵机水平旋转底座。</li>
      </ul>
    </aside>
  </div>
  <script type="module">
    import * as THREE from 'https://unpkg.com/three@0.160.0/build/three.module.js';
    import { OrbitControls } from 'https://unpkg.com/three@0.160.0/examples/jsm/controls/OrbitControls.js';
    const canvas = document.getElementById('view');
    const renderer = new THREE.WebGLRenderer({ canvas, antialias: true });
    const scene = new THREE.Scene();
    scene.background = new THREE.Color(0xdfe7ef);
    const camera = new THREE.PerspectiveCamera(45, 1, 0.1, 1000);
    camera.position.set(105, -120, 80);
    const controls = new OrbitControls(camera, renderer.domElement);
    controls.target.set(0, 0, 22);
    controls.update();
    scene.add(new THREE.HemisphereLight(0xffffff, 0x667788, 2.4));
    const light = new THREE.DirectionalLight(0xffffff, 1.5);
    light.position.set(80, -100, 120);
    scene.add(light);
    const grid = new THREE.GridHelper(140, 14, 0x8da2b6, 0xb8c7d6);
    grid.rotation.x = Math.PI / 2;
    scene.add(grid);
    function addBox(name, size, pos, color, opacity = 1) {
      const geo = new THREE.BoxGeometry(size[0], size[1], size[2]);
      const mat = new THREE.MeshStandardMaterial({ color, transparent: opacity < 1, opacity, roughness: 0.55, metalness: 0.02 });
      const mesh = new THREE.Mesh(geo, mat);
      mesh.position.set(pos[0], pos[1], pos[2]);
      mesh.name = name;
      scene.add(mesh);
      const edges = new THREE.LineSegments(new THREE.EdgesGeometry(geo), new THREE.LineBasicMaterial({ color: 0x2b3642 }));
      edges.position.copy(mesh.position);
      scene.add(edges);
    }
    function addCylinder(name, radius, depth, pos, rot, color) {
      const geo = new THREE.CylinderGeometry(radius, radius, depth, 48);
      const mat = new THREE.MeshStandardMaterial({ color, roughness: 0.5 });
      const mesh = new THREE.Mesh(geo, mat);
      mesh.position.set(pos[0], pos[1], pos[2]);
      mesh.rotation.set(rot[0], rot[1], rot[2]);
      mesh.name = name;
      scene.add(mesh);
    }
    addBox('主壳体', [82, 62, 30], [0, 0, 33], 0x7db7ff, 0.38);
    addBox('内部空间', [68, 48, 23], [0, 0, 31.5], 0xf5f7fa, 0.22);
    addCylinder('摄像头孔', 7, 5, [0, -33, 37], [Math.PI / 2, 0, 0], 0x111827);
    addBox('USB-C开孔', [12, 5, 7], [0, 33, 28], 0x111827);
    for (let i = -2; i <= 2; i++) addBox('顶部散热孔', [5, 24, 2], [i * 9, 0, 48], 0x0f766e);
    addBox('PCB', [70, 50, 1.6], [0, 0, 22.8], 0x22c55e, 0.8);
    addBox('底盖', [82, 62, 2], [0, 0, 13], 0x9ca3af, 0.85);
    addBox('舵机底座', [62, 48, 16], [0, 0, 0], 0xf59e0b, 0.72);
    addBox('舵机本体空间', [24, 13, 22], [0, 0, 7], 0x7c2d12, 0.32);
    addCylinder('舵机输出轴', 4, 8, [0, 0, 12], [0, 0, 0], 0x374151);
    function resize() {
      const w = canvas.clientWidth, h = canvas.clientHeight;
      renderer.setSize(w, h, false);
      camera.aspect = w / h;
      camera.updateProjectionMatrix();
    }
    function animate() {
      resize();
      renderer.render(scene, camera);
      requestAnimationFrame(animate);
    }
    animate();
  </script>
</body>
</html>`;

fs.writeFileSync(path.join(outDir, 'cat_watch_enclosure_preview.html'), html, 'utf8');
const simpleHtml = `<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>猫咪看护外壳离线预览</title>
  <style>
    body { margin: 0; font-family: Arial, "Microsoft YaHei", sans-serif; background:#f2f5f8; color:#17202a; }
    main { max-width: 980px; margin: 0 auto; padding: 20px; }
    svg { width: 100%; height: auto; background:#e6edf4; border:1px solid #cad5df; border-radius:8px; }
    h1 { font-size:22px; }
    p, li { line-height:1.7; }
  </style>
</head>
<body>
<main>
  <h1>猫咪看护外壳离线预览</h1>
  <p>这个页面不需要联网。它是简化等轴图，用来快速看外壳结构关系；真实 3D 模型请打开同目录 OBJ/STL，或使用带 Three.js 的 HTML 预览。</p>
  <svg viewBox="0 0 900 560" role="img" aria-label="外壳等轴预览">
    <defs>
      <linearGradient id="body" x1="0" x2="1">
        <stop offset="0" stop-color="#98c7ff"/>
        <stop offset="1" stop-color="#5aa0f2"/>
      </linearGradient>
      <linearGradient id="base" x1="0" x2="1">
        <stop offset="0" stop-color="#fbbf24"/>
        <stop offset="1" stop-color="#f59e0b"/>
      </linearGradient>
    </defs>
    <polygon points="310,170 575,110 710,210 445,270" fill="#b9d9ff" stroke="#263849" stroke-width="2"/>
    <polygon points="310,170 445,270 445,405 310,305" fill="url(#body)" stroke="#263849" stroke-width="2"/>
    <polygon points="445,270 710,210 710,345 445,405" fill="#6eaef6" stroke="#263849" stroke-width="2"/>
    <polygon points="310,305 445,405 710,345 575,465" fill="#9ca3af" opacity="0.65" stroke="#263849" stroke-width="2"/>
    <ellipse cx="372" cy="260" rx="34" ry="24" fill="#111827" stroke="#f8fafc" stroke-width="4"/>
    <text x="322" y="236" fill="#111827" font-size="18">摄像头开孔</text>
    <rect x="665" y="273" width="42" height="28" fill="#111827" stroke="#f8fafc" stroke-width="2"/>
    <text x="690" y="260" fill="#111827" font-size="18">USB-C</text>
    <g fill="#0f766e" opacity="0.9">
      <polygon points="408,170 430,165 448,178 426,183"/>
      <polygon points="450,160 472,155 490,168 468,173"/>
      <polygon points="492,151 514,146 532,159 510,164"/>
      <polygon points="534,142 556,137 574,150 552,155"/>
    </g>
    <text x="470" y="128" fill="#0f766e" font-size="18">顶部散热孔</text>
    <polygon points="365,430 530,390 650,470 485,520" fill="url(#base)" stroke="#263849" stroke-width="2"/>
    <polygon points="365,430 485,520 485,545 365,455" fill="#d97706" stroke="#263849" stroke-width="2"/>
    <polygon points="485,520 650,470 650,495 485,545" fill="#f59e0b" stroke="#263849" stroke-width="2"/>
    <text x="410" y="500" fill="#111827" font-size="18">舵机底座</text>
    <rect x="481" y="444" width="72" height="38" rx="4" fill="#7c2d12" opacity="0.45" stroke="#431407"/>
    <circle cx="516" cy="425" r="16" fill="#374151" stroke="#111827" stroke-width="2"/>
    <text x="540" y="430" fill="#111827" font-size="18">舵机轴</text>
  </svg>
  <ul>
    <li>主壳体：放 PCB、摄像头和 ESP32-S3。</li>
    <li>前方圆孔：OV3660 摄像头开孔。</li>
    <li>后方小孔：USB-C 线缆接口。</li>
    <li>顶部绿色长孔：散热孔。</li>
    <li>底部黄色部分：可选舵机底座。</li>
  </ul>
</main>
</body>
</html>`;
fs.writeFileSync(path.join(outDir, 'cat_watch_enclosure_offline_preview.html'), simpleHtml, 'utf8');
console.log(`Generated preview files in ${outDir}`);
