package main

import rl "vendor:raylib"
import "core:math"
import "core:thread"
import "core:mem"
import "core:math/rand"
import "core:fmt"
import "core:strings"
import rc "/raycaster"


screen_width : i32 = 2000
screen_height : i32 = 2000
play_width : f32 = 1000
score_width : f32 = f32(screen_width) - play_width

SHIP_SIZE : i32 = 30

Thread_Object :: struct {
    raycaster : ^rc.Raycaster,
    shapes : ^[dynamic]rc.Shape,
    points : [dynamic]rc.Intercept_Point,
}



num_threads := 2

main :: proc()
{
    // Initialization
    //--------------------------------------------------------------------------------------

    track: mem.Tracking_Allocator
    mem.tracking_allocator_init(&track, context.allocator)
    context.allocator = mem.tracking_allocator(&track)

    temp_track: mem.Tracking_Allocator
    mem.tracking_allocator_init(&temp_track, context.temp_allocator)
    context.temp_allocator = mem.tracking_allocator(&temp_track)

    defer {
        if len(temp_track.allocation_map) > 0 {
            fmt.eprintf("=== %v allocations not freed: ===\n", len(temp_track.allocation_map))
            for _, entry in temp_track.allocation_map {
                fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
            }
        }
        if len(temp_track.bad_free_array) > 0 {
            fmt.eprintf("=== %v incorrect frees: ===\n", len(temp_track.bad_free_array))
            for entry in temp_track.bad_free_array {
                fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
            }
        }
        mem.tracking_allocator_destroy(&temp_track)

        if len(track.allocation_map) > 0 {
            fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
            for _, entry in track.allocation_map {
                fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
            }
        }
        if len(track.bad_free_array) > 0 {
            fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
            for entry in track.bad_free_array {
                fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
            }
        }
        mem.tracking_allocator_destroy(&track)
    }

    rl.SetConfigFlags(rl.ConfigFlags{rl.ConfigFlag.WINDOW_TRANSPARENT});

    rl.InitWindow(screen_width, screen_height, "Raycast - basic window");
    rl.HideCursor()

    ray_caster := rc.Make_Raycaster(rl.Vector2{0,0},360, 360, 1000)

    shapes := [dynamic]rc.Shape{
        rc.Circle{f32(screen_width/2), f32(screen_height/2), 50},
        rc.Circle{200, 200, 50},
        rc.Circle{300, 300, 50},
        rc.Circle{400, 400, 50},
        rc.Circle{500, 500, 50},
        rc.Circle{600, 600, 50},
        rc.Circle{700, 700, 50},
        rc.Circle{800, 800, 50},
        rc.Circle{900, 900, 50},
        rc.Circle{1000, 1000, 50},
        rl.Rectangle{1100, 1100, 50, 50},
        rl.Rectangle{1200, 1200, 50, 50},
        rl.Rectangle{1300, 1300, 50, 50},
        rl.Rectangle{1400, 1400, 50, 50},
        rl.Rectangle{1100, 1300, 50, 50},
        rl.Rectangle{1200, 1500, 50, 50},
        rl.Rectangle{1300, 1600, 50, 50},
        rl.Rectangle{1400, 1700, 50, 50},
    }

    

    worker_proc :: proc(t: ^thread.Thread){

        data := cast(^Thread_Object)t.data
        raycaster := data.raycaster
        shapes := data.shapes
        id := t.id
        index := t.user_index

        range := len(data.points)
        start := 0
        end := range
        
        for j in start..<end  {
            nearst := math.inf_f32(1)
            for i in 0..<len(shapes){
                s := shapes[i]
                ray_index := j + index * range 

                p, intercept := rc.Ray_Intercept_Shape(raycaster.rays[ray_index], &s)
                
                if intercept{
                    //data.points[j].intercept = intercept
                    d := rl.Vector2Distance(raycaster.rays[ray_index].origin, p)
                    if d <= nearst {
                        nearst = d
                        data.points[j].point = p
                        data.points[j].intercept = intercept
                    }
                    
                }
                
            }
        }
    }

    //rl.SetTargetFPS(120) // Set our game to run at 60 frames-per-second
    //--------------------------------------------------------------------------------------
    rl.SetTraceLogLevel(rl.TraceLogLevel.ALL) // Show trace log messages (LOG_INFO, LOG_WARNING, LOG_ERROR, LOG_DEBUG)
    // Main game loop
    for !rl.WindowShouldClose()    // Detect window close button or ESC key
    {
        // Update
        //----------------------------------------------------------------------------------
        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)
        
        mouse_pos := rl.GetMousePosition()
        if rl.IsMouseButtonPressed(rl.MouseButton.LEFT) {
            for i in 0..<100 {
                mouse_pos.x += rand.float32()*10 - 5
                mouse_pos.y += rand.float32()*10 - 5
            }
        }
        
        
        threads := make([dynamic]^thread.Thread, 0, num_threads)
        points := make([dynamic]rc.Intercept_Point, len(ray_caster.rays))
        defer delete(threads)
        for _ in 0..<num_threads {
            if t := thread.create(worker_proc); t != nil{
                
                t.init_context = context
                t.user_index = len(threads)
                to := new(Thread_Object)
                to.raycaster = ray_caster
                to.shapes = &shapes

                range := len(ray_caster.rays) / num_threads
                start := range * len(threads)
                end := start + range
                if len(threads) == num_threads - 1 {
                    end = len(ray_caster.rays)
                }
                p := make([dynamic]rc.Intercept_Point, end - start)
                to.points = p
                t.data = to
                append(&threads, t)
                thread.start(t)
            }
        }

        for len(threads) > 0{
            for i := 0; i < len(threads); {
                if t := threads[i]; thread.is_done(t){
                    to := cast(^Thread_Object)t.data
                    for j in 0..<len(to.points) {
                        index := j + t.user_index * len(to.points)
                        //rl.TraceLog(rl.TraceLogLevel.INFO, "Thread: %d Index : %d Value %f,%5f", t.user_index, index, to.points[j].x, to.points[j].y)
                        points[index] = to.points[j]
                    }
                    delete(to.points)
                    free(t.data)
                    thread.destroy(t)
                    ordered_remove(&threads, i)
                } else {
                    i += 1
                }
            }
        }

        for i in 0..<len(points) {
            rl.DrawCircle(i32(points[i].point.x), i32(points[i].point.y), 5, rl.RED)     
        }
        
        rc.Update_Raycaster(ray_caster, mouse_pos, points, 360)
        rc.Draw_Raycaster(ray_caster)

        for i in 0..<len(shapes) {
            rc.Draw_Shape(&shapes[i])
        }

        st_mouse_pos :=  rl.TextFormat( "%v, %v", mouse_pos.x ,mouse_pos.y)
        rl.DrawText(st_mouse_pos, i32(mouse_pos.x), i32(mouse_pos.y), 20, rl.WHITE)
              
        
        fps := rl.GetFPS()
        rl.DrawText(rl.TextFormat("FPS: %v", fps), 10, 30, 20, rl.RED)
        rl.EndDrawing()
        delete(points)
        free_all(context.temp_allocator)
    }

    // De-Initialization
   
    delete(ray_caster.rays)
    delete(shapes)
    free(&ray_caster.rays)
    

    rl.CloseWindow()
}