const overlay = document.getElementById('overlay');
const ctx = overlay.getContext('2d');
const streamWrap = document.getElementById('streamWrap');
const buttons = [...document.querySelectorAll('[data-region]')];
const saveRegions = document.getElementById('saveRegions');
const servo = document.getElementById('servo');
const servoOut = document.getElementById('servoOut');

const colors = {
  bed: '#22c55e',
  bowl: '#f97316',
  left_exit: '#0ea5e9',
  right_exit: '#a855f7',
};

const regionNames = {
  bed: '窝',
  bowl: '饭碗',
  left_exit: '左出口',
  right_exit: '右出口',
};

const stateNames = {
  unknown: '未知',
  visible: '画面内',
  resting: '休息',
  eating: '吃饭',
  away: '离开画面',
  left_exit: '向左离开',
  right_exit: '向右离开',
};

let regions = {};
let activeRegion = 'bed';
let dragStart = null;

function setActive(name) {
  activeRegion = name;
  buttons.forEach((button) => button.classList.toggle('active', button.dataset.region === name));
}

function canvasPoint(event) {
  const rect = overlay.getBoundingClientRect();
  const x = Math.round((event.clientX - rect.left) * overlay.width / rect.width);
  const y = Math.round((event.clientY - rect.top) * overlay.height / rect.height);
  return { x, y };
}

function normalizeRect(a, b) {
  const x = Math.min(a.x, b.x);
  const y = Math.min(a.y, b.y);
  return {
    x,
    y,
    w: Math.max(1, Math.abs(a.x - b.x)),
    h: Math.max(1, Math.abs(a.y - b.y)),
  };
}

function draw() {
  ctx.clearRect(0, 0, overlay.width, overlay.height);
  Object.entries(regions).forEach(([name, r]) => {
    if (!r) return;
    ctx.strokeStyle = colors[name] || '#ffffff';
    ctx.lineWidth = 2;
    ctx.strokeRect(r.x, r.y, r.w, r.h);
    ctx.fillStyle = colors[name] || '#ffffff';
    ctx.font = '14px Arial';
    ctx.fillText(regionNames[name] || name, r.x + 4, Math.max(16, r.y + 16));
  });
}

buttons.forEach((button) => {
  button.addEventListener('click', () => setActive(button.dataset.region));
});

overlay.addEventListener('pointerdown', (event) => {
  dragStart = canvasPoint(event);
  overlay.setPointerCapture(event.pointerId);
});

overlay.addEventListener('pointermove', (event) => {
  if (!dragStart) return;
  regions[activeRegion] = normalizeRect(dragStart, canvasPoint(event));
  draw();
});

overlay.addEventListener('pointerup', () => {
  dragStart = null;
  draw();
});

saveRegions.addEventListener('click', async () => {
  await fetch('/api/regions', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(regions),
  });
  await refreshStatus();
});

let servoTimer = null;
servo.addEventListener('input', () => {
  servoOut.value = servo.value;
  clearTimeout(servoTimer);
  servoTimer = setTimeout(() => {
    fetch('/api/servo', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ angle: Number(servo.value) }),
    });
  }, 120);
});

async function refreshStatus() {
  const res = await fetch('/api/status');
  const data = await res.json();
  regions = data.regions || regions;
  document.getElementById('state').textContent = stateNames[data.state] || data.state;
  document.getElementById('score').textContent = Number(data.last_score || 0).toFixed(3);
  document.getElementById('heap').textContent = data.heap_free;
  document.getElementById('psram').textContent = data.psram_free;
  document.getElementById('wifi').textContent = data.wifi_connected ? '已连接' : '未连接';
  servo.value = data.servo_angle;
  servoOut.value = data.servo_angle;
  draw();
}

async function refreshEvents() {
  const res = await fetch('/api/events');
  const events = await res.json();
  const list = document.getElementById('events');
  list.innerHTML = '';
  events.slice().reverse().forEach((event) => {
    const li = document.createElement('li');
    const name = stateNames[event.state] || event.state;
    li.textContent = `${name}  持续=${event.duration_ms}ms  置信度=${Number(event.score).toFixed(2)}`;
    list.appendChild(li);
  });
}

setActive(activeRegion);
refreshStatus();
refreshEvents();
setInterval(refreshStatus, 2000);
setInterval(refreshEvents, 5000);
