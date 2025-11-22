const WebSocket = require('ws');
const robot = require('robotjs');

const wss = new WebSocket.Server({ port: 8989 });

console.log("Touchpad server running ws://0.0.0.0:8989");

wss.on('connection', ws => {
  console.log("Phone connected!");

  ws.on('message', raw => {
    const msg = JSON.parse(raw);

    if (msg.type === "move") {
      const pos = robot.getMousePos();
      robot.moveMouse(pos.x + msg.dx, pos.y + msg.dy);
    }

    if (msg.type === "scroll") {
      robot.scrollMouse(msg.dx, msg.dy);
    }

    if (msg.type === "click") {
      robot.mouseClick(msg.button);
    }

    if (msg.type === "zoom") {
      // Mô phỏng zoom bằng scroll
      const delta = (msg.scale - 1) * 40;
      robot.scrollMouse(0, delta);
    }
  });
});
