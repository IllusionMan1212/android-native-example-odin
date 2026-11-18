package android_native_example

import "base:runtime"

import "core:log"
import glue "core:sys/android/native_app_glue"
import "core:sys/android"

import "vendor:egl"
import gl "vendor:OpenGL"

engine :: struct {
    app: ^glue.android_app,

    active: bool,
    display: egl.Display,
    surface: egl.Surface,
    ctx: egl.Context,
    width: i32,
    height: i32,

    buffer: u32,
    shader: u32,
}

engine_init_display :: proc "contextless" (engine: ^engine) {
    context = runtime.default_context()
    attribs := []i32{
        egl.SURFACE_TYPE, egl.WINDOW_BIT,
        egl.RENDERABLE_TYPE, egl.OPENGL_ES3_BIT,
        egl.BLUE_SIZE, 8,
        egl.GREEN_SIZE, 8,
        egl.RED_SIZE, 8,
        egl.NONE,
    }

    display := egl.GetDisplay(egl.DEFAULT_DISPLAY)
    if display == egl.NO_DISPLAY {
        log.info("error with eglGetDisplay")
        return
    }

    if !egl.Initialize(display, nil, nil) {
        log.info("error with eglInitialize")
        return
    }

    // NOTE: I think the major and minor versions don't matter here, we just want the gl package to load all available
    // gl procs.
    gl.load_up_to(
        4,
        6,
        proc(p: rawptr, name: cstring) {(cast(^rawptr)p)^ = egl.GetProcAddress(name)}
    )

    config: egl.Config
    numConfigs: i32
    if !egl.ChooseConfig(display, raw_data(attribs), &config, 1, &numConfigs) {
        log.info("error with eglChooseConfig")
        return
    }

    format: i32
    if !egl.GetConfigAttrib(display, config, egl.NATIVE_VISUAL_ID, &format) {
        log.info("error with eglGetConfigAttrib")
        return
    }

    android.ANativeWindow_setBuffersGeometry(engine.app.window, 0, 0, cast(android.AHardwareBuffer_Format)format)

    surface := egl.CreateWindowSurface(display, config, cast(egl.NativeWindowType)engine.app.window, nil)
    if surface == nil {
        log.info("error with eglCreateWindowSurface")
        return
    }

    ctx_attrib := []i32{ egl.CONTEXT_CLIENT_VERSION, 2, egl.NONE }
    ctx := egl.CreateContext(display, config, nil, raw_data(ctx_attrib))
    if ctx == nil {
        log.info("error with eglCreateContext")
        return
    }

    if !egl.MakeCurrent(display, surface, surface, ctx) {
        log.info("error with eglMakeCurrent")
        return
    }

    log.infof("GL_VENDOR = %s", gl.GetString(gl.VENDOR))
    log.infof("GL_RENDERER = %s", gl.GetString(gl.RENDERER))
    log.infof("GL_VERSION = %s", gl.GetString(gl.VERSION))

    w: i32
    h: i32
    egl.QuerySurface(display, surface, egl.WIDTH, &w)
    egl.QuerySurface(display, surface, egl.HEIGHT, &h)

    log.infof("initial width: %d", w)
    log.infof("initial height: %d", h)

    gl.Viewport(0, 0, w, h)

    engine.display = display
    engine.ctx = ctx
    engine.surface = surface
    engine.width = w
    engine.height = h

    vasset := android.AAssetManager_open(engine.app.activity.assetManager, "vertex.glsl", .BUFFER)
    if vasset == nil {
        log.info("error opening vertex.glsl")
        return
    }
    defer android.AAsset_close(vasset)
    vsrc := cstring(android.AAsset_getBuffer(vasset))
    vlen := i32(android.AAsset_getLength(vasset))

    v := gl.CreateShader(gl.VERTEX_SHADER)
    gl.ShaderSource(v, 1, &vsrc, &vlen)
    gl.CompileShader(v)

    fasset := android.AAssetManager_open(engine.app.activity.assetManager, "fragment.glsl", .BUFFER)
    if fasset == nil {
        log.info("error opening fragment.glsl")
        return
    }
    defer android.AAsset_close(fasset)
    fsrc := cstring(android.AAsset_getBuffer(fasset))
    flen := i32(android.AAsset_getLength(fasset))

    f := gl.CreateShader(gl.FRAGMENT_SHADER)
    gl.ShaderSource(f, 1, &fsrc, &flen)
    gl.CompileShader(f)


    p := gl.CreateProgram()
    gl.AttachShader(p, v)
    gl.AttachShader(p, f)

    gl.BindAttribLocation(p, 0, "vPosition")
    gl.BindAttribLocation(p, 1, "vColor")
    gl.LinkProgram(p)

    gl.DeleteShader(v)
    gl.DeleteShader(f)
    gl.UseProgram(p)

    buf := [?]f32 {
         0.0,  0.5, 1, 0, 0,
        -0.5, -0.5, 0, 1, 0,
         0.5, -0.5, 0, 0, 1,
    }

    b: u32
    gl.GenBuffers(1, &b)
    gl.BindBuffer(gl.ARRAY_BUFFER, b)
    gl.BufferData(gl.ARRAY_BUFFER, size_of(buf), &buf, gl.STATIC_DRAW)

    engine.buffer = b
    engine.shader = p
}

engine_draw_frame :: proc "contextless" (engine: ^engine) {
    if engine.display == nil {
        return
    }

    gl.ClearColor(0.258824, 0.258824, 0.435294, 1)
    gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

    gl.UseProgram(engine.shader)

    gl.BindBuffer(gl.ARRAY_BUFFER, engine.buffer)
    gl.VertexAttribPointer(0, 2, gl.FLOAT, gl.FALSE, (2+3)*size_of(f32), 0)
    gl.VertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, (2+3)*size_of(f32), (2*size_of(f32)))
    gl.EnableVertexAttribArray(0)
    gl.EnableVertexAttribArray(1)

    gl.DrawArrays(gl.TRIANGLES, 0, 3)

    egl.SwapBuffers(engine.display, engine.surface)
}

engine_term_display :: proc "contextless" (engine: ^engine) {
    if engine.display != egl.NO_DISPLAY {
        gl.DeleteProgram(engine.shader)
        gl.DeleteBuffers(1, &engine.buffer)

        egl.MakeCurrent(engine.display, egl.NO_SURFACE, egl.NO_SURFACE, egl.NO_CONTEXT)
        if engine.ctx != egl.NO_CONTEXT {
            egl.DestroyContext(engine.display, engine.ctx)
        }
        if engine.surface != egl.NO_SURFACE {
            egl.DestroySurface(engine.display, engine.surface)
        }
        egl.Terminate(engine.display)
    }
    engine.active = false
    engine.display = egl.NO_DISPLAY
    engine.ctx = egl.NO_CONTEXT
    engine.surface = egl.NO_SURFACE
}

engine_handle_input :: proc(app: ^glue.android_app, event: ^android.AInputEvent) -> i32 {
    return 0
}

engine_handle_cmd :: proc (app: ^glue.android_app, cmd: i32) {
    engine := cast(^engine)app.userData

    switch cmd {
        case glue.APP_CMD_INIT_WINDOW:
            if engine.app.window != nil {
                log.info("init window event")
                engine_init_display(engine)
                engine_draw_frame(engine)
            }

        case glue.APP_CMD_TERM_WINDOW:
            log.info("term window event")
            engine_term_display(engine)
        case glue.APP_CMD_WINDOW_RESIZED:
            log.info("window resized")
            h := android.ANativeWindow_getHeight(app.window)
            w := android.ANativeWindow_getWidth(app.window)
            log.infof("w: %d", w)
            log.infof("h: %d", h)
            gl.Viewport(0, 0, w, h)
        
        case glue.APP_CMD_GAINED_FOCUS:
            log.info("gained focus event")
            engine.active = true

        case glue.APP_CMD_LOST_FOCUS:
            log.info("lost focus event")
            engine.active = false
            engine_draw_frame(engine)
    }
}

main :: proc() {
    context.logger = log.create_console_logger(ident="NativeExampleOdin")
    engine: engine

    app := glue.app()
    app.userData = &engine
    app.onAppCmd = engine_handle_cmd
    app.onInputEvent = engine_handle_input
    engine.app = app

    for app.destroyRequested == 0 {
        source: ^glue.android_poll_source

        if android.ALooper_pollOnce(engine.active ? 0 : -1, nil, nil, cast(^rawptr)&source) >= 0 && source != nil {
            source.process(app, source)
        }

        if (engine.active) {
            engine_draw_frame(&engine)
        }
    }

    engine_term_display(&engine)
}
