var gl = null;
var memory = null;
var vaos = [];
var programs = [];

function loadShader(gl, type, source) {
  // console.log('Type of gl is: ', typeof(gl), gl);
  const shader = gl.createShader(type);

  gl.shaderSource(shader, source);

  gl.compileShader(shader);

  if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
    alert(
      `An error occurred compiling the shaders: ${gl.getShaderInfoLog(shader)}`,
    );
    gl.deleteShader(shader);
    return null; 
  } 
  return shader;
}

function compileLinkProgramWasm(vs, vs_len, fs, fs_len) {
  const vs_source = new Uint8Array(memory.buffer, vs, vs_len)
  const fs_source = new Uint8Array(memory.buffer, fs, fs_len)
  const dec = new TextDecoder('utf-8');
  const program = compileLinkProgram(dec.decode(vs_source), dec.decode(fs_source));
  programs.push(program);
  return programs.length - 1;
}


function compileLinkProgram(vertex_source, fragment_source) {
  const vertexShader = loadShader(gl, gl.VERTEX_SHADER, vertex_source);
  const fragmentShader = loadShader(gl, gl.FRAGMENT_SHADER, fragment_source);

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
  }
  return shaderProgram
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
  gl.bufferData(gl.ARRAY_BUFFER, positions, gl.STATIC_DRAW);
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


function bind2DFloat32DataWasm(d, len) {
  const arr = new Float32Array(memory.buffer, d, len);
  vaos.push(bind2DFloat32Data(arr));
  return vaos.length - 1;
}



async function init() {
  const canvas = document.getElementById("canvas");
  gl = canvas.getContext("webgl2");
  if (gl === null) {
    console.log('failed to get webgl context :(')
  } else {
    console.log('yay! loaded webgl context :)')
  }// Vertex shader program



  const mod = await WebAssembly.instantiateStreaming(fetch("/zig-out/bin/index.wasm"), {
    env: {
      compileLinkProgram: compileLinkProgramWasm,
      bind2DFloat32Data: bind2DFloat32DataWasm,
      glBindVertexArray: (vao) => gl.bindVertexArray(vaos[vao]),
      glClearColor: gl.clearColor.bind(gl),
      glClear: gl.clear.bind(gl),
      glUseProgram: (program) => {
        gl.useProgram(programs[program])
      },
      glDrawArrays: gl.drawArrays.bind(gl),
      // glPointSize: gl.pointSize().bind(gl),
    }
  });
  memory = mod.instance.exports.memory;
  console.log(mod.instance.exports.add(1, 2));
  mod.instance.exports.run();

  // const vsSource = `
  //     attribute vec4 aVertexPosition;
  //     void main() {
  //       gl_Position = aVertexPosition;
  //     }
  //   `;
  //
  // const fsSource = `
  //   void main() {
  //     gl_FragColor = vec4(1.0, 1.0, 1.0, 1.0);
  //   }
  // `;
  //
  // // Now create an array of positions for the square.
  // const program = compileLinkProgram(vsSource, fsSource);
  // const positions = new Float32Array([0.5, 0.5, -0.5, 0.5, 0.5, -0.5, -0.5, -0.5]);
  // const vao = bind2DFloat32Data(positions, vsSource, fsSource);
  //
  //
  // gl.clearColor(0.0, 0.0, 1.0, 1.0);
  // gl.clear(gl.COLOR_BUFFER_BIT);
  //
  // gl.useProgram(program);
  // {
  //   const offset = 0;
  //   const vertexCount = 4;
  //   gl.drawArrays(gl.TRIANGLE_STRIP, offset, vertexCount);
  // }
};

window.onload = init
