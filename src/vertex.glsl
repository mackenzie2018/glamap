#version 300 es
precision highp float;

in vec4 aVertexPosition;
uniform float lat_centre;
uniform float lon_centre;
void main() {
  gl_Position = aVertexPosition;
  // 0.0 => lat_centre,
  gl_Position.y -= lat_centre; // 55.66385;
  gl_Position.y *= 5.0;
  gl_Position.y -= 1.0;
  gl_Position.x += lon_centre; // 4.724538;
  gl_Position.x *= 5.0;
  gl_Position.x -= 2.25;
  gl_PointSize = 0.01;
}
