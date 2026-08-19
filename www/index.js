var gl = null;
var memory = null;
var vaos = [];
var programs = [];
var uniform_locs = [];




function logWasm(s, len) {
  const buf = new Uint8Array(memory.buffer, s, len);
  console.log(new TextDecoder('utf-8').decode(buf));
}



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
  const positionBuffer = gl.createBuffer();
  gl.bindBuffer(gl.ARRAY_BUFFER, positionBuffer);
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

function getUniformLocWasm(program, namep, name_len) {
  const name_data = new Uint8Array(memory.buffer, namep, name_len);
  const name = (new TextDecoder('utf-8')).decode(name_data);
  uniform_locs.push(gl.getUniformLocation(programs[program], name));
  return uniform_locs.length - 1;
}



async function init() {
  const canvas = document.getElementById("canvas");
  canvas.width = canvas.clientWidth;
  canvas.height = canvas.clientHeight;
  gl = canvas.getContext("webgl2");
  if (gl === null) {
    console.log('failed to get webgl context :(')
  } else {
    console.log('yay! loaded webgl context :)')
  }

  const mod = await WebAssembly.instantiateStreaming(
    fetch("/zig-out/bin/index.wasm"),
    {
      env: {
        logWasm: logWasm,
        compileLinkProgram: compileLinkProgramWasm,
        bind2DFloat32Data: bind2DFloat32DataWasm,
        glBindVertexArray: (vao) => gl.bindVertexArray(vaos[vao]),
        glClearColor: gl.clearColor.bind(gl),
        glClear: gl.clear.bind(gl),
        glUseProgram: (program) => {
          gl.useProgram(programs[program])
        },
        glDrawArrays: gl.drawArrays.bind(gl),
        glGetUniformLoc: getUniformLocWasm,
        glUniform1f: (loc, val) => {
          gl.uniform1f(uniform_locs[loc], val);
        },
        // glPointSize: gl.pointSize().bind(gl),
      }
    });
  memory = mod.instance.exports.memory;
  mod.instance.exports.init();

  const map_data_response = await fetch("map_data.bin");
  const data_reader = map_data_response.body.getReader({
    mode: 'byob',
  });
  let array_buf = new ArrayBuffer(16384);
  while (true) {
    // const array_buf = new ArrayBuffer(4096);
    const { value, done } = await data_reader.read(new Uint8Array(array_buf));
    if (done) break;

    array_buf = value.buffer;
    const chunk_buf = new Uint8Array(memory.buffer, mod.instance.exports.global_chunk.value, 16384);
    chunk_buf.set(value);
    mod.instance.exports.pushData(value.length);
  }

  mod.instance.exports.init_program();



  canvas.onmousedown = (ev) => {
    const rect = canvas.getBoundingClientRect();
    mod.instance.exports.mouseDown(
      (ev.clientX - rect.left) / rect.width,
      (ev.clientY - rect.top) / rect.height,
    );
  };


  canvas.onmouseup = () => {
    mod.instance.exports.mouseUp();
  };

  canvas.onmousemove = (ev) => {
    const rect = canvas.getBoundingClientRect();
    mod.instance.exports.mouseMove(
      (ev.clientX - rect.left) / rect.width,
      (ev.clientY - rect.top) / rect.height,
    );
  };

  canvas.onwheel = (ev) => {
    // console.log(ev);
    mod.instance.exports.zoom(ev.deltaY);
  };

  mod.instance.exports.render();
};

window.onload = init
