package raycaster

import "core:math"
import rl "vendor:raylib"



Ray :: struct {
    origin: rl.Vector2,
    direction: rl.Vector2,
    view_distance: f32,
    max_distance: f32,
}

Intercept_Point :: struct {
    point : rl.Vector2,
    intercept : bool,
}

Raycaster :: struct{
    rays: [dynamic]Ray,
    num_rays: i32,
    fov: f32,
    max_distance: f32,
}

Make_Raycaster :: proc(origin: rl.Vector2, num_rays: i32, fov: f32, max_distance: f32) -> ^Raycaster {
    rc := new(Raycaster)
    rc.num_rays = num_rays
    rc.fov = fov
    rc.max_distance = max_distance
    rc.rays = make([dynamic]Ray, num_rays)
    angle := f32(0)
    for i in 0..< rc.num_rays{
        rc.rays[i].origin = origin
        angle = angle + fov / f32(num_rays)
        radians := angle * math.PI / 180
        rc.rays[i].direction = rl.Vector2{math.cos(radians), math.sin(radians)}
        rc.rays[i].view_distance = max_distance
        rc.rays[i].max_distance = max_distance
    }
    return rc
}

Update_Raycaster :: proc(rc : ^Raycaster, origin: rl.Vector2, points: [dynamic]Intercept_Point, fov: f32) {
    //rc.fov = fov
    
    angle := f32(0)
    for i in 0..< rc.num_rays{
        rc.rays[i].origin = origin
        angle = angle + fov / f32(rc.num_rays)
        radians := angle * math.PI / 180
        rc.rays[i].direction = rl.Vector2{math.cos(radians), math.sin(radians)}
        if points[i].intercept {
            rc.rays[i].view_distance = rl.Vector2Distance(rc.rays[i].origin, points[i].point)
        }
        else{
            rc.rays[i].view_distance = rc.max_distance
        }
    }
}


Draw_Raycaster :: proc(rc: ^Raycaster) {
    for i in 0..<rc.num_rays {
        p := rc.rays[i].origin
        x := i32(p.x)
        y := i32(p.y)
        xl := i32(p.x + rc.rays[i].direction.x * rc.rays[i].view_distance)
        yl := i32(p.y + rc.rays[i].direction.y * rc.rays[i].view_distance)
        rl.DrawLine(x,y,xl,yl, rl.WHITE)
    }
}

Circle :: struct {
    x: f32,
    y: f32,
    radius: f32,
}

Shape :: union{
    rl.Rectangle,
    Circle,
}

Ray_Intercept_Shape :: proc(ray: Ray, shape: ^Shape) -> (rl.Vector2, bool){
    switch s in shape {
        case rl.Rectangle : {
            return ray_intercept_rectangle(ray, cast(^rl.Rectangle)shape)
        }
        case Circle:{
            return ray_intercept_circle(ray, cast(^Circle)shape)
        }
    }

    return rl.Vector2{0,0}, false

}

ray_intercept_rectangle :: proc(ray: Ray, rect: ^rl.Rectangle) -> (rl.Vector2, bool) {
    // Unpack rectangle properties
    min_x := rect.x
    min_y := rect.y
    max_x := rect.x + rect.width
    max_y := rect.y + rect.height

    // Ray properties
    origin := ray.origin
    dir := ray.direction

    t_near := math.inf_f32(-1)
    t_far := math.inf_f32(1)

    // Check intersection with vertical boundaries
    if abs(dir.x) > 1e-8 {  // Avoid division by zero
        t1 := (min_x - origin.x) / dir.x
        t2 := (max_x - origin.x) / dir.x
        t_near = max(t_near, min(t1, t2))
        t_far = min(t_far, max(t1, t2))
    } else if origin.x < min_x || origin.x > max_x {
        return rl.Vector2{}, false
    }

    // Check intersection with horizontal boundaries
    if abs(dir.y) > 1e-8 {  // Avoid division by zero
        t1 := (min_y - origin.y) / dir.y
        t2 := (max_y - origin.y) / dir.y
        t_near = max(t_near, min(t1, t2))
        t_far = min(t_far, max(t1, t2))
    } else if origin.y < min_y || origin.y > max_y {
        return rl.Vector2{}, false
    }

    // Check if there's a valid intersection
    if t_near > t_far || t_far < 0 || t_near > ray.max_distance {
        return rl.Vector2{}, false
    }

    // Use t_near for the intersection point
    t := max(t_near, 0)  // Ensure we don't go backwards along the ray

    // Calculate intersection point
    intersection := rl.Vector2{
        origin.x + t * dir.x,
        origin.y + t * dir.y,
    }

    // Double-check if the intersection point is within the rectangle bounds
    if intersection.x < min_x || intersection.x > max_x ||
       intersection.y < min_y || intersection.y > max_y {
        return rl.Vector2{}, false
    }

    if math.is_inf(t) {
        return rl.Vector2{}, false
    }

    return intersection, true
}

ray_intercept_circle :: proc(ray: Ray, circle: ^Circle) -> (rl.Vector2, bool) {
    
    o := ray.origin
    d := ray.direction
    oc_x := o.x - circle.x  
    oc_y := o.y - circle.y 
    a : f32 = 1
    b : f32 = 2*(d.x*oc_x + d.y*oc_y)
    c : f32 = oc_x*oc_x + oc_y*oc_y - circle.radius*circle.radius

    discriminant := b*b - 4*a*c
    if discriminant < 0 {
        return rl.Vector2{0,0}, false
    }

    t1 := (-b + math.sqrt(discriminant)) / (2*a)
    t2 := (-b - math.sqrt(discriminant)) / (2*a)

    //# Choose the smallest positive t that is less than or equal to max_distance
    if t1 < 0 || t1 > ray.max_distance {
        t1 = math.inf_f32(1)
    }
    if t2 < 0 || t2 > ray.max_distance {
        t2 = math.inf_f32(1)
    }
    t := math.min(t1, t2)

    if math.is_inf(t) {
        return rl.Vector2{0,0}, false
    }
    
    // rl.TraceLog(rl.TraceLogLevel.INFO, "t: %f", t)
    v := rl.Vector2{o.x + d.x*t, o.y + d.y*t}
    // rl.TraceLog(rl.TraceLogLevel.INFO, "v: %f, %f", v.x, v.y)
    return v, true
    
}    
    


Draw_Shape :: proc(shape: ^Shape) {
    switch _ in shape {
        case rl.Rectangle : {
            s := cast(^rl.Rectangle)shape
            rl.DrawRectangleLines(i32(s.x), i32(s.y), i32(s.width), i32(s.height), rl.WHITE)
        }
        case Circle : {
            s := cast(^Circle)shape
            rl.DrawCircleLines(i32(s.x), i32(s.y), s.radius, rl.WHITE)
        }
    }
}