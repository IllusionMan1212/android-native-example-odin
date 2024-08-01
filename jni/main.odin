package android_native_example

import "base:runtime"

import "shared:android"

import "vendor:egl"
import gl "vendor:OpenGL"

LOG :: android.__android_log_print

engine :: struct {
    app: ^android.android_app,

    active: bool,
    display: egl.Display,
    surface: egl.Surface,
    ctx: egl.Context,
    width: i32,
    height: i32,

    buffer: u32,
    shader: u32,
}

engine_init_display :: proc(engine: ^engine) {
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
        LOG(.INFO, "NativeExampleOdin", "Naterror with eglGetDisplay")
        return
    }

    if !egl.Initialize(display, nil, nil) {
        LOG(.INFO, "NativeExampleOdin", "error with eglInitialize")
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
        LOG(.INFO, "NativeExampleOdin", "error with eglChooseConfig")
        return
    }

    format: i32
    if !egl.GetConfigAttrib(display, config, egl.NATIVE_VISUAL_ID, &format) {
        LOG(.INFO, "NativeExampleOdin", "error with eglGetConfigAttrib")
        return
    }

    android.ANativeWindow_setBuffersGeometry(engine.app.window, 0, 0, format)

    surface := egl.CreateWindowSurface(display, config, cast(egl.NativeWindowType)engine.app.window, nil)
    if surface == nil {
        LOG(.INFO, "NativeExampleOdin", "error with eglCreateWindowSurface")
        return
    }

    ctx_attrib := []i32{ egl.CONTEXT_CLIENT_VERSION, 2, egl.NONE }
    ctx := egl.CreateContext(display, config, nil, raw_data(ctx_attrib))
    if ctx == nil {
        LOG(.INFO, "NativeExampleOdin", "error with eglCreateContext")
        return
    }

    if !egl.MakeCurrent(display, surface, surface, ctx) {
        LOG(.INFO, "NativeExampleOdin", "error with eglMakeCurrent")
        return
    }

    LOG(.INFO, "NativeExampleOdin", "GL_VENDOR = %s", gl.GetString(gl.VENDOR))
    LOG(.INFO, "NativeExampleOdin", "GL_RENDERER = %s", gl.GetString(gl.RENDERER))
    LOG(.INFO, "NativeExampleOdin", "GL_VERSION = %s", gl.GetString(gl.VERSION))

    w: i32
    h: i32
    egl.QuerySurface(display, surface, egl.WIDTH, &w)
    egl.QuerySurface(display, surface, egl.HEIGHT, &h)

    LOG(.INFO, "NativeExampleOdin", "initial width: %d", w)
    LOG(.INFO, "NativeExampleOdin", "initial height: %d", h)

    gl.Viewport(0, 0, w, h)

    engine.display = display
    engine.ctx = ctx
    engine.surface = surface
    engine.width = w
    engine.height = h

    vasset := android.AAssetManager_open(engine.app.activity.assetManager, "vertex.glsl", .BUFFER)
    defer android.AAsset_close(vasset)
    if vasset == nil {
        LOG(.INFO, "NativeExampleOdin", "error opening vertex.glsl")
        return
    }
    vsrc := cstring(android.AAsset_getBuffer(vasset))
    vlen := i32(android.AAsset_getLength(vasset))

    v := gl.CreateShader(gl.VERTEX_SHADER)
    gl.ShaderSource(v, 1, &vsrc, &vlen)
    gl.CompileShader(v)

    fasset := android.AAssetManager_open(engine.app.activity.assetManager, "fragment.glsl", .BUFFER)
    defer android.AAsset_close(fasset)
    if fasset == nil {
        LOG(.INFO, "NativeExampleOdin", "error opening fragment.glsl")
        return
    }
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

    return
}

engine_draw_frame :: proc(engine: ^engine) {
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

engine_term_display :: proc(engine: ^engine) {
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

engine_handle_input :: proc(app: ^android.android_app, event: ^android.AInputEvent) -> i32 {
    return 0
}

engine_handle_cmd :: proc(app: ^android.android_app, cmd: android.AppCmd) {
    engine := cast(^engine)app.userData

    #partial switch (cmd) {
        case .INIT_WINDOW:
            if engine.app.window != nil {
                LOG(.INFO, "NativeExampleOdin", "init window event")
                engine_init_display(engine)
                engine_draw_frame(engine)
            }

        case .TERM_WINDOW:
            LOG(.INFO, "NativeExampleOdin", "term window event")
            engine_term_display(engine)
        case .WINDOW_RESIZED:
            LOG(.INFO, "NativeExampleOdin", "window resized")
            h := android.ANativeWindow_getHeight(app.window)
            w := android.ANativeWindow_getWidth(app.window)
            LOG(.INFO, "NativeExampleOdin", "w: %d", w)
            LOG(.INFO, "NativeExampleOdin", "h: %d", h)
            gl.Viewport(0, 0, w, h)
        
        case .GAINED_FOCUS:
            LOG(.INFO, "NativeExampleOdin", "gained focus event")
            engine.active = true

        case .LOST_FOCUS:
            LOG(.INFO, "NativeExampleOdin", "lost focus event")
            engine.active = false
            engine_draw_frame(engine)
    }
}

@export
android_main :: proc "contextless" (state: ^android.android_app) {
    context = runtime.default_context()

    engine: engine

    state.userData = &engine
    state.onAppCmd = engine_handle_cmd
    state.onInputEvent = engine_handle_input
    engine.app = state

    for {
        events: i32
        source: ^android.android_poll_source

        ident := android.ALooper_pollAll(engine.active ? 0 : -1, nil, &events, cast(^rawptr)&source)
        for ident >= 0 {
            if source != nil {
                source.process(state, source)
            }

            if state.destroyRequested != 0 {
                engine_term_display(&engine)
                return
            }

            ident = android.ALooper_pollAll(engine.active ? 0 : -1, nil, &events, cast(^rawptr)&source)
        }

        if (engine.active) {
            engine_draw_frame(&engine)
        }
    }
}
