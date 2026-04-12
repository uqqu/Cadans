temp_pts := []
temp_opt := 0
gest_cache := Map()
PI := 3.141592653589793


GetPool(x, y) {
    static mp:=[5, 4, 6, "-lr-", 2, 1, 3, "-tb-", 8, 7, 9]
    ;  6 5 7
    ;  2 1 3
    ; 10 9 11

    l := x <= CONF.edge_size.v
    r := x >= (A_ScreenWidth - CONF.edge_size.v)
    t := y <= CONF.edge_size.v
    b := y >= (A_ScreenHeight - CONF.edge_size.v)

    switch CONF.edge_gestures.v {
        case 1:  ; without edges/corners
            return 5
        case 2:  ; only edges
            pre := (l | (r << 1) | (t << 2) | (b << 3)) + 1
            w := A_ScreenWidth - x
            h := A_ScreenHeight - y
            return mp[pre == 6 ? (x > y ? 5 : 2)
                : pre == 7 ? (w > y ? 5 : 3)
                : pre == 10 ? (h > x ? 2 : 9)
                : pre == 11 ? (h > w ? 3 : 9) : pre]
        case 3:  ; only corners
            pre := (l | (r << 1) | (t << 2) | (b << 3)) + 1
            return mp[[2, 3, 5, 9].Has(pre) ? 1 : pre]
        case 4:  ; both
            return mp[(l | (r << 1) | (t << 2) | (b << 3)) + 1]
    }
}


Resample(pts) {
    total := 0
    seg_len := []
    loop pts.Length - 1 {
        d := Sqrt((pts[A_Index+1][1]-pts[A_Index][1])**2
            + (pts[A_Index+1][2]-pts[A_Index][2])**2)
        seg_len.Push(d)
        total += d
    }

    step := total / 63
    out := [[pts[1][1], pts[1][2]]]

    target := step
    acc := 0
    i := 1
    while out.Length < 63 {
        if i > seg_len.Length {
            break
        }

        if acc + seg_len[i] < target {
            acc += seg_len[i]
            i++
            continue
        }

        t := (target - acc) / (seg_len[i] || 1)
        out.Push([
            pts[i][1] + (pts[i+1][1]-pts[i][1]) * t,
            pts[i][2] + (pts[i+1][2]-pts[i][2]) * t
        ])

        target += step
    }

    out.Push([pts[-1][1], pts[-1][2]])

    return [out, total]
}


Flatten(pts) {
    vec := []
    for p in pts {
        vec.Push(p[1], p[2])
    }
    return vec
}


Normalize(pts) {
    s := 0
    for v in pts {
        s += v[1]*v[1] + v[2]*v[2]
    }
    s := Sqrt(s)

    _norm := []
    if s {
        loop pts.Length {
            _norm.Push([pts[A_Index][1] / s, pts[A_Index][2] / s])
        }
    }
    return _norm
}


Rotate(pts, fixed:=false) {
    dx := pts[2][1] - pts[1][1]
    dy := pts[2][2] - pts[1][2]

    if !dx {
        ang := dy > 0 ? (PI/2) : (dy < 0 ? -PI/2 : 0)
    } else {
        ang := ATan(dy / dx)
        if dx < 0 {
            ang += dy >= 0 ? PI : -PI
        }
    }

    if Abs(ang) < 1e-6 {
        return pts.Clone()
    }
    if fixed {
        return _RotatePoints(pts, -ang)
    }

    step := PI / 4
    snapped := Round(ang/step) * step
    return _RotatePoints(pts, -ang + snapped)
}


_RotatePoints(pts, angle_rad) {
    c := Cos(angle_rad)
    s := Sin(angle_rad)
    out := []
    for p in pts {
        x := p[1]
        y := p[2]
        out.Push([x*c - y*s, x*s + y*c])
    }

    return out
}


_VecNorm(a) {
    s := 0
    for v in a {
        s += v * v
    }
    return Sqrt(s)
}


Recognize(raw_pts, gestures) {
    global gest_cache, temp_opt, temp_pts

    res := Resample(raw_pts)
    pts := res[1]
    closed := Sqrt((pts[1][1]-pts[-1][1])**2 + (pts[1][2]-pts[-1][2])**2) < (res[2] / 10)
    gest_cache := Map()
    gest_cache[1] := Map()
    best_gesture := ""
    best_score := -1
    for gesture in gestures {
        cur_pts := pts

        loop 2 {
            dir_i := A_Index - 1
            if !(closed && _GetFin(gesture).opts.closed) {
                score := _ScoreAtPhase(0, _GetFin(gesture), cur_pts, closed, dir_i)
            } else {
                best_phase := 0
                score := -1

                for step in [16, 4, 1] {  ; 64/4, 16/4, 4/4
                    for delta in [(A_Index == 1 ? 0 : -2*step), -step, step, 2*step] {
                        phase := Mod(best_phase + delta + 64, 64) + 1
                        s := _ScoreAtPhase(phase, _GetFin(gesture), cur_pts, closed, dir_i)
                        if s > score {
                            score := s
                            best_phase := phase
                        }
                    }
                }
            }

            if score > best_score {
                best_score := score
                best_gesture := gesture
            }

            if !_GetFin(gesture).opts.dirs || A_Index == 2 {
                break
            }
            cur_pts := []
            loop 64 {
                cur_pts.Push(pts[-A_Index])
            }
        }
    }

    return [best_score, best_gesture]
}


Centering(pts) {
    cx := pts[1][1]
    cy := pts[1][2]
    moved := []
    for p in pts {
        moved.Push([p[1] - cx, p[2] - cy])
    }
    return moved
}


_ScoreAtPhase(phase, gesture, pts, closed, opt) {
    global gest_cache, temp_opt, temp_pts

    key := phase + 1  ; 1-indexed

    if !gest_cache.Has(key) {
        gest_cache[key] := Map()
    }

    temp_opt := opt
    temp_pts := PhaseShift(pts, phase)

    _CacheAdd(true, 1, key, Centering, temp_pts)
    r := gesture.opts.rotate == 2
    _CacheAdd(gesture.opts.rotate, (r ? 2 : 4), key, Rotate, temp_pts, r)
    _CacheAdd(gesture.opts.scaling = 0, 8, key, Normalize, temp_pts)
    _CacheAdd(true, 16, key, Flatten, temp_pts)

    if gesture.opts.scaling != 0 && !gest_cache[key].Has(temp_opt + 32) {
        gest_cache[key][temp_opt + 32] := _VecNorm(temp_pts)
    }

    if gesture.opts.scaling = 0 {
        score := CosineSim(gesture.vec, temp_pts)
    } else {
        score := CosineSim(gesture.vec, temp_pts, gesture.opts.scaling,
            gesture.opts.len, gest_cache[key][temp_opt + 32])
    }

    return score
}


PhaseShift(pts, shft) {
    if !shft {
        return pts
    }

    out := []
    out.Length := 64
    loop 64 {
        out[A_Index] := pts[Mod(shft + A_Index - 1, 64) + 1]
    }
    return out
}


_CacheAdd(condition, opt_val, idx, function, args*) {
    global temp_opt, temp_pts

    if condition {
        temp_opt += opt_val
        if !gest_cache[idx].Has(temp_opt) {
            gest_cache[idx][temp_opt] := function(args*)
        }
        temp_pts := gest_cache[idx][temp_opt]
    }
}


CosineSim(vec_a, vec_b, beta:=0, len_a?, len_b?) {
    s := 0
    for i, a in vec_a {
        s += a * vec_b[i]
    }
    return !beta ? s : (s / (len_a*len_b) * Exp(-beta * Abs(Ln(len_a/len_b))))
}


GestureToStr(raw_pts, rot, scaling, dirs, phase) {
    pts := Resample(raw_pts)[1]
    pool := GetPool(pts[1][1], pts[1][2])
    rot1 := rot == 3
    rot8 := rot == 2

    if phase {
        pts := _CloseGestureSeamPts(pts, 0.2)
    }

    pts := Centering(pts)
    if rot1 || rot8 {
        pts := Rotate(pts, rot1)
    }
    if scaling = 0 {
        pts := Normalize(pts)
    }

    vec := Flatten(pts)

    opt_str := pool . ";" . (rot1 ? 2 : (rot8 ? 1 : 0)) . ";" . Format("{:0.2f}", scaling) . ";"
        . Integer(dirs) . ";" . Integer(phase) . ";" . Round(_VecNorm(vec))

    vec_str := pool . " "
    for v in vec {
        vec_str .= Format("{:0.8f}", v) . " "
    }

    return [vec_str, opt_str]
}


_CloseGestureSeamPts(pts, blend_portion:=0.2) {
    pts_cnt := pts.Length
    if pts_cnt < 3 {
        return pts.Clone()
    }

    out := []
    for pt in pts {
        out.Push([pt[1], pt[2]])
    }

    first_x := pts[1][1]
    first_y := pts[1][2]
    last_x := pts[pts_cnt][1]
    last_y := pts[pts_cnt][2]

    anchor_x := (first_x + last_x) / 2
    anchor_y := (first_y + last_y) / 2

    start_dx := anchor_x - first_x
    start_dy := anchor_y - first_y
    end_dx := anchor_x - last_x
    end_dy := anchor_y - last_y

    blend_pts := Max(1, Round((pts_cnt - 1) * blend_portion))

    i := 0
    while i <= blend_pts {
        idx := i + 1
        t := i / blend_pts
        w := (1 - t) * (1 - t)

        out[idx][1] := pts[idx][1] + start_dx * w
        out[idx][2] := pts[idx][2] + start_dy * w
        i += 1
    }

    i := 0
    while i <= blend_pts {
        idx := pts_cnt - i
        t := i / blend_pts
        w := (1 - t) * (1 - t)

        out[idx][1] := out[idx][1] + end_dx * w
        out[idx][2] := out[idx][2] + end_dy * w
        i += 1
    }

    out[1][1] := anchor_x
    out[1][2] := anchor_y
    out[pts_cnt][1] := anchor_x
    out[pts_cnt][2] := anchor_y

    return out
}