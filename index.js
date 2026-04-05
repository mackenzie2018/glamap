var gl = null;

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


function compileLinkProgram(gl, vertex_source, fragment_source) {
  const vertexShader = loadShader(gl, gl.VERTEX_SHADER, vertex_source);
  const fragmentShader = loadShader(gl, gl.FRAGMENT_SHADER, fragment_source);

  // Create the shader program

  const program = gl.createProgram();
  gl.attachShader(program, vertexShader);
  gl.attachShader(program, fragmentShader);
  gl.linkProgram(program);

  if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
    alert(
      `Unable to initialize the shader program: ${gl.getProgramInfoLog(
        program,
      )}`,
    );
  }
  return program
}


function bind2DFloat32Data(positions, vsSource, fsSource) {

  // Create a buffer for the square's positions.
  const positionBuffer = gl.createBuffer();

  // Select the positionBuffer as the one to apply buffer
  // operations to from here out.
  gl.bindBuffer(gl.ARRAY_BUFFER, positionBuffer);


  // Now pass the list of positions into WebGL to build the
  // shape. We do this by creating a Float32Array from the
  // JavaScript array, then use it to fill the current buffer.
  gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(positions), gl.STATIC_DRAW);
  const vao = gl.createVertexArray()
  gl.bindVertexArray(vao);
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
  return vao;
}



async function init() {
  // const importObject = {
  //   env: {
  //     // Add any functions your Zig code imports here
  //     "add",
  //   },
  // };
  const mod = await WebAssembly.instantiateStreaming(fetch("/zig-out/bin/index.wasm"), {});
  console.log(mod.instance.exports.add(1, 2));
  const response = await fetch("/zig-out/bin/index.wasm");
  const buffer = await response.arrayBuffer();
  const module = await WebAssembly.compile(buffer);
  console.log(WebAssembly.Module.imports(module));
  const canvas = document.getElementById("canvas");
  gl = canvas.getContext("webgl");
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

  // Now create an array of positions for the square.
  const program = compileLinkProgram(gl, vsSource, fsSource);
  const positions = [0.5, 0.5, -0.5, 0.5, 0.5, -0.5, -0.5, -0.5];
  const vao = bind2DFloat32Data(positions, vsSource, fsSource);


  gl.clearColor(0.0, 0.0, 1.0, 1.0);
  gl.clear(gl.COLOR_BUFFER_BIT);

  gl.useProgram(program);
  {
    const offset = 0;
    const vertexCount = 4;
    gl.drawArrays(gl.TRIANGLE_STRIP, offset, vertexCount);
  }
};

window.onload = init
