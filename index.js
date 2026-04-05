function loadShader(gl, type, source) {
  const shader = gl.createShader(type);

  // Send the source to the shader object

  gl.shaderSource(shader, source);

  // Compile the shader program

  gl.compileShader(shader);

  // See if it compiled successfully

  if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
    alert(
      `An error occurred compiling the shaders: ${gl.getShaderInfoLog(shader)}`,
    );
    gl.deleteShader(shader);
    return null;
  }

  return shader;
}


async function init() {
  // console.log("hello from script")
  const canvas = document.getElementById("canvas");
  const gl = canvas.getContext("webgl");
  if (gl === null) {
    console.log('failed to get webgl context :(')
  } else {
    console.log('yay! loaded webgl context :)')
  }// Vertex shader program
  const vsSource = `
      attribute vec4 aVertexPosition;
      void main() {
        gl_Position = aVertexPosition;
      }
    `;

  const fsSource = `
    void main() {
      gl_FragColor = vec4(1.0, 1.0, 1.0, 1.0);
    }
  `;

  const vertexShader = loadShader(gl, gl.VERTEX_SHADER, vsSource);
  const fragmentShader = loadShader(gl, gl.FRAGMENT_SHADER, fsSource);

  // Create the shader program

  const shaderProgram = gl.createProgram();
  gl.attachShader(shaderProgram, vertexShader);
  gl.attachShader(shaderProgram, fragmentShader);
  gl.linkProgram(shaderProgram);

   if (!gl.getProgramParameter(shaderProgram, gl.LINK_STATUS)) {
    alert(
      `Unable to initialize the shader program: ${gl.getProgramInfoLog(
        shaderProgram,
      )}`,
    );
    return null;
  }

  // Create a buffer for the square's positions.
  const positionBuffer = gl.createBuffer();

  // Select the positionBuffer as the one to apply buffer
  // operations to from here out.
  gl.bindBuffer(gl.ARRAY_BUFFER, positionBuffer);

  // Now create an array of positions for the square.
  const positions = [0.5, 0.5, -0.5, 0.5, 0.5, -0.5, -0.5, -0.5];

  // Now pass the list of positions into WebGL to build the
  // shape. We do this by creating a Float32Array from the
  // JavaScript array, then use it to fill the current buffer.
  gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(positions), gl.STATIC_DRAW);
  const vertex_attrib = 0;
  const numComponents = 2; // pull out 2 values per iteration
  const type = gl.FLOAT; // the data in the buffer is 32bit floats
  const normalize = false; // don't normalize
  const stride = 0; // how many bytes to get from one set of values to the next
  // 0 = use type and numComponents above
  const offset = 0; // how many bytes inside the buffer to start from
  gl.vertexAttribPointer(
    vertex_attrib,
    numComponents,
    type,
    normalize,
    stride,
    offset,
  );
  gl.enableVertexAttribArray(vertex_attrib);

  gl.clearColor(0.0, 0.0, 1.0, 1.0);
  gl.clear(gl.COLOR_BUFFER_BIT);

  gl.useProgram(shaderProgram);
  {
    const offset = 0;
    const vertexCount = 4;
    gl.drawArrays(gl.TRIANGLE_STRIP, offset, vertexCount);
  }
} 

window.onload = init
