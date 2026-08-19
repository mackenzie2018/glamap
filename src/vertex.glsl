#version 300 es
precision highp float;

in vec4 aVertexPosition;
uniform float lat_centre;
uniform float lon_centre;
uniform float zoom;
void main() {
  // gl_Position = aVertexPosition;
  // 0.0 => lat_centre,
  // gl_Position.y -= aVertexPosition.y - lat_centre; // 55.66385;
  // gl_Position.y *= 3.0;
  // gl_Position.y -= 1.0;
  // gl_Position.x += aVertexPosition.x - lon_centre; // 4.724538;
  // gl_Position.x *= 2.1;
  // gl_Position.x -= 1.0;
  // gl_PointSize = 0.05;
  gl_Position = aVertexPosition;
  gl_Position.y -= lat_centre;
  gl_Position.y *= 3.0 * zoom;
  gl_Position.x -= lon_centre;
  gl_Position.x *= 2.1 * zoom;
  gl_PointSize = 0.5;
}
