
# https://github.com/jheinen/GR.jl

# significant contributions by @jheinen

supported_args(::GRBackend) = merge_with_base_supported([
    :annotations,
    :background_color_legend, :background_color_inside, :background_color_outside,
    :foreground_color_legend, :foreground_color_grid, :foreground_color_axis,
    :foreground_color_text, :foreground_color_border,
    :label,
    :seriescolor, :seriesalpha,
    :linecolor, :linestyle, :linewidth, :linealpha,
    :markershape, :markercolor, :markersize, :markeralpha,
    :markerstrokewidth, :markerstrokecolor, :markerstrokealpha,
    :fillrange, :fillcolor, :fillalpha,
    :bins,
    :layout,
    :title, :window_title,
    :guide, :lims, :ticks, :scale, :flip,
    :tickfont, :guidefont, :legendfont,
    :grid, :legend, :colorbar,
    :marker_z, :levels,
    :ribbon, :quiver,
    :orientation,
    :overwrite_figure,
    :polar,
    :aspect_ratio,
    :normalize, :weights,
    :inset_subplots,
])
supported_types(::GRBackend) = [
    :path, :scatter,
    :heatmap, :pie, :image,
    :contour, :path3d, :scatter3d, :surface, :wireframe,
    :shape
]
supported_styles(::GRBackend) = [:auto, :solid, :dash, :dot, :dashdot, :dashdotdot]
supported_markers(::GRBackend) = vcat(_allMarkers, Shape)
supported_scales(::GRBackend) = [:identity, :log10]
is_subplot_supported(::GRBackend) = true


function _initialize_backend(::GRBackend; kw...)
    @eval begin
        import GR
        export GR
    end
end

# --------------------------------------------------------------------------------------

const gr_linetype = KW(
    :auto => 1,
    :solid => 1,
    :dash => 2,
    :dot => 3,
    :dashdot => 4,
    :dashdotdot => -1
)

const gr_markertype = KW(
    :auto => 1,
    :none => -1,
    :circle => -1,
    :rect => -7,
    :diamond => -13,
    :utriangle => -3,
    :dtriangle => -5,
    :pentagon => -21,
    :hexagon => -22,
    :heptagon => -23,
    :octagon => -24,
    :cross => 2,
    :xcross => 5,
    :star4 => -25,
    :star5 => -26,
    :star6 => -27,
    :star7 => -28,
    :star8 => -29,
    :vline => -30,
    :hline => -31
)

const gr_halign = KW(
    :left => 1,
    :hcenter => 2,
    :right => 3
)

const gr_valign = KW(
    :top => 1,
    :vcenter => 3,
    :bottom => 5
)

const gr_font_family = Dict(
    "times" => 1,
    "helvetica" => 5,
    "courier" => 9,
    "bookman" => 14,
    "newcenturyschlbk" => 18,
    "avantgarde" => 22,
    "palatino" => 26
)

# --------------------------------------------------------------------------------------

function gr_getcolorind(v, a =nothing)
    c = getColor(v)
    idx = convert(Int, GR.inqcolorfromrgb(c.r, c.g, c.b))
    GR.settransparency(float(a==nothing ? alpha(c) : a))
    idx
end

gr_set_linecolor(c, a=nothing) = GR.setlinecolorind(gr_getcolorind(c, a))
gr_set_fillcolor(c, a=nothing) = GR.setfillcolorind(gr_getcolorind(c, a))
gr_set_markercolor(c, a=nothing) = GR.setmarkercolorind(gr_getcolorind(c, a))
gr_set_textcolor(c, a=nothing) = GR.settextcolorind(gr_getcolorind(c, a))

# --------------------------------------------------------------------------------------


# draw line segments, splitting x/y into contiguous/finite segments
# note: this can be used for shapes by passing func `GR.fillarea`
function gr_polyline(x, y, func = GR.polyline)
    iend = 0
    n = length(x)
    while iend < n-1
        # set istart to the first index that is finite
        istart = -1
        for j = iend+1:n
            if isfinite(x[j]) && isfinite(y[j])
                istart = j
                break
            end
        end

        if istart > 0
            # iend is the last finite index
            iend = -1
            for j = istart+1:n
                if isfinite(x[j]) && isfinite(y[j])
                    iend = j
                else
                    break
                end
            end
        end

        # if we found a start and end, draw the line segment, otherwise we're done
        if istart > 0 && iend > 0
            func(x[istart:iend], y[istart:iend])
        else
            break
        end
    end
end

function gr_inqtext(x, y, s)
    if length(s) >= 2 && s[1] == '$' && s[end] == '$'
        GR.inqtextext(x, y, s[2:end-1])
    elseif search(s, '\\') != 0 || search(s, '_') != 0 || search(s, '^') != 0
        GR.inqtextext(x, y, s)
    else
        GR.inqtext(x, y, s)
    end
end

function gr_text(x, y, s)
    if length(s) >= 2 && s[1] == '$' && s[end] == '$'
        GR.mathtex(x, y, s[2:end-1])
    elseif search(s, '\\') != 0 || search(s, '_') != 0 || search(s, '^') != 0
        GR.textext(x, y, s)
    else
        GR.text(x, y, s)
    end
end

function gr_polaraxes(rmin, rmax)
    GR.savestate()
    GR.setlinetype(GR.LINETYPE_SOLID)
    GR.setlinecolorind(88)
    tick = 0.5 * GR.tick(rmin, rmax)
    n = round(Int, (rmax - rmin) / tick + 0.5)
    for i in 0:n
        r = float(i) / n
        if i % 2 == 0
            GR.setlinecolorind(88)
            if i > 0
                GR.drawarc(-r, r, -r, r, 0, 359)
            end
            GR.settextalign(GR.TEXT_HALIGN_LEFT, GR.TEXT_VALIGN_HALF)
            x, y = GR.wctondc(0.05, r)
            GR.text(x, y, string(signif(rmin + i * tick, 12)))
        else
            GR.setlinecolorind(90)
            GR.drawarc(-r, r, -r, r, 0, 359)
        end
    end
    for alpha in 0:45:315
        a = alpha + 90
        sinf = sin(a * pi / 180)
        cosf = cos(a * pi / 180)
        GR.polyline([sinf, 0], [cosf, 0])
        GR.settextalign(GR.TEXT_HALIGN_CENTER, GR.TEXT_VALIGN_HALF)
        x, y = GR.wctondc(1.1 * sinf, 1.1 * cosf)
        GR.textext(x, y, string(alpha, "^o"))
    end
    GR.restorestate()
end


# using the axis extrema and limit overrides, return the min/max value for this axis
gr_x_axislims(sp::Subplot) = axis_limits(sp[:xaxis])
gr_y_axislims(sp::Subplot) = axis_limits(sp[:yaxis])
gr_z_axislims(sp::Subplot) = axis_limits(sp[:zaxis])
gr_xy_axislims(sp::Subplot) = gr_x_axislims(sp)..., gr_y_axislims(sp)...

function gr_lims(axis::Axis, adjust::Bool, expand = nothing)
    if expand != nothing
        expand_extrema!(axis, expand)
    end
    lims = axis_limits(axis)
    if adjust
        GR.adjustrange(lims...)
    else
        lims
    end
end


function gr_fill_viewport(vp::AVec{Float64}, c)
    GR.savestate()
    GR.selntran(0)
    GR.setfillintstyle(GR.INTSTYLE_SOLID)
    gr_set_fillcolor(c)
    GR.fillrect(vp...)
    GR.selntran(1)
    GR.restorestate()
end


normalize_zvals(zv::Void) = zv
function normalize_zvals(zv::AVec)
    vmin, vmax = extrema(zv)
    if vmin == vmax
        zeros(length(zv))
    else
        (zv - vmin) ./ (vmax - vmin)
    end
end

# ---------------------------------------------------------

# draw ONE Shape
function gr_draw_marker(xi, yi, msize, shape::Shape)
    sx, sy = shape_coords(shape)
    GR.selntran(0)
    xi, yi = GR.wctondc(xi, yi)
    GR.fillarea(xi + sx * 0.0015msize,
                yi + sy * 0.0015msize)
    GR.selntran(1)
end

# draw ONE symbol marker
function gr_draw_marker(xi, yi, msize::Number, shape::Symbol)
    GR.setmarkertype(gr_markertype[shape])
    GR.setmarkersize(0.3msize)
    GR.polymarker([xi], [yi])
end


# draw the markers, one at a time
function gr_draw_markers(d::KW, x, y, msize, mz)
    shape = d[:markershape]
    if shape != :none
        for i=1:length(x)
            msi = cycle(msize, i)
            cfunc = isa(shape, Shape) ? gr_set_fillcolor : gr_set_markercolor
            cfuncind = isa(shape, Shape) ? GR.setfillcolorind : GR.setmarkercolorind

            # draw a filled in shape, slightly bigger, to estimate a stroke
            cfunc(d[:markerstrokecolor], d[:markerstrokealpha])
            gr_draw_marker(x[i], y[i], msi*1.2, shape, )

            # draw the shape
            if mz == nothing
                cfunc(d[:markercolor], d[:markeralpha])
            else
                # pick a color from the pre-loaded gradient
                ci = round(Int, 1000 + cycle(mz, i) * 255)
                cfuncind(ci)
            end
            gr_draw_marker(x[i], y[i], msi, shape)
        end
    end
end

function gr_draw_markers(series::Series, x, y)
    isempty(x) && return
    d = series.d
    mz = normalize_zvals(d[:marker_z])
    GR.setfillintstyle(GR.INTSTYLE_SOLID)
    gr_draw_markers(d, x, y, d[:markersize], mz)
    if mz != nothing
        gr_colorbar(d[:subplot])
    end
end

# ---------------------------------------------------------

function gr_set_line(w, style, c, a)
    GR.setlinetype(gr_linetype[style])
    GR.setlinewidth(w)
    gr_set_linecolor(c, a)
end



function gr_set_fill(c, a)
    gr_set_fillcolor(c, a)
    GR.setfillintstyle(GR.INTSTYLE_SOLID)
end

# this stores the conversion from a font pointsize to "percentage of window height" (which is what GR uses)
const _gr_point_mult = zeros(1)

# set the font attributes... assumes _gr_point_mult has been populated already
function gr_set_font(f::Font)
    family = lowercase(f.family)
    GR.setcharheight(_gr_point_mult[1] * f.pointsize)
    GR.setcharup(sin(f.rotation), cos(f.rotation))
    if haskey(gr_font_family, family)
        GR.settextfontprec(100 + gr_font_family[family], GR.TEXT_PRECISION_STRING)
    end
    gr_set_textcolor(f.color)
    GR.settextalign(gr_halign[f.halign], gr_valign[f.valign])
end

# --------------------------------------------------------------------------------------
# viewport plot area

# this stays constant for a given subplot while displaying that subplot.
# values are [xmin, xmax, ymin, ymax].  they range [0,1].
const viewport_plotarea = zeros(4)

function gr_viewport_from_bbox(bb::BoundingBox, w, h, viewport_canvas)
    viewport = zeros(4)
    viewport[1] = viewport_canvas[2] * (left(bb) / w)
    viewport[2] = viewport_canvas[2] * (right(bb) / w)
    viewport[3] = viewport_canvas[4] * (1.0 - bottom(bb) / h)
    viewport[4] = viewport_canvas[4] * (1.0 - top(bb) / h)
    viewport
end

# change so we're focused on the viewport area
function gr_set_viewport_cmap(sp::Subplot)
    GR.setviewport(
        viewport_plotarea[2] + (is3d(sp) ? 0.04 : 0.02),
        viewport_plotarea[2] + (is3d(sp) ? 0.07 : 0.05),
        viewport_plotarea[3],
        viewport_plotarea[4]
    )
end

# reset the viewport to the plot area
function gr_set_viewport_plotarea()
    GR.setviewport(
        viewport_plotarea[1],
        viewport_plotarea[2],
        viewport_plotarea[3],
        viewport_plotarea[4]
    )
end

function gr_set_viewport_polar()
    xmin, xmax, ymin, ymax = viewport_plotarea
    ymax -= 0.05 * (xmax - xmin)
    xcenter = 0.5 * (xmin + xmax)
    ycenter = 0.5 * (ymin + ymax)
    r = 0.5 * min(xmax - xmin, ymax - ymin)
    GR.setviewport(xcenter -r, xcenter + r, ycenter - r, ycenter + r)
    GR.setwindow(-1, 1, -1, 1)
    r
end

# add the colorbar
function gr_colorbar(sp::Subplot)
    if sp[:colorbar] != :none
        gr_set_viewport_cmap(sp)
        GR.colormap()
        gr_set_viewport_plotarea()
    end
end

gr_view_xcenter() = 0.5 * (viewport_plotarea[1] + viewport_plotarea[2])
gr_view_ycenter() = 0.5 * (viewport_plotarea[3] + viewport_plotarea[4])
gr_view_xdiff() = viewport_plotarea[2] - viewport_plotarea[1]
gr_view_ydiff() = viewport_plotarea[4] - viewport_plotarea[3]


# --------------------------------------------------------------------------------------


function gr_set_gradient(c, a)
    grad = isa(c, ColorGradient) ? c : default_gradient()
    grad = ColorGradient(grad, alpha=a)
    for (i,z) in enumerate(linspace(0, 1, 256))
        c = getColorZ(grad, z)
        GR.setcolorrep(999+i, red(c), green(c), blue(c))
    end
    grad
end

# this is our new display func... set up the viewport_canvas, compute bounding boxes, and display each subplot
function gr_display(plt::Plot)
    GR.clearws()

    # collect some monitor/display sizes in meters and pixels
    display_width_meters, display_height_meters, display_width_px, display_height_px = GR.inqdspsize()
    display_width_ratio = display_width_meters / display_width_px
    display_height_ratio = display_height_meters / display_height_px

    # compute the viewport_canvas, normalized to the larger dimension
    viewport_canvas = Float64[0,1,0,1]
    w, h = plt[:size]
    if w > h
        ratio = float(h) / w
        msize = display_width_ratio * w
        GR.setwsviewport(0, msize, 0, msize * ratio)
        GR.setwswindow(0, 1, 0, ratio)
        viewport_canvas[3] *= ratio
        viewport_canvas[4] *= ratio
    else
        ratio = float(w) / h
        msize = display_height_ratio * h
        GR.setwsviewport(0, msize * ratio, 0, msize)
        GR.setwswindow(0, ratio, 0, 1)
        viewport_canvas[1] *= ratio
        viewport_canvas[2] *= ratio
    end

    # fill in the viewport_canvas background
    gr_fill_viewport(viewport_canvas, plt[:background_color_outside])

    # update point mult
    px_per_pt = px / pt
    _gr_point_mult[1] = px_per_pt / h

    # subplots:
    for sp in plt.subplots
        gr_display(sp, w*px, h*px, viewport_canvas)
    end

    GR.updatews()
end


function gr_display(sp::Subplot{GRBackend}, w, h, viewport_canvas)
    # the viewports for this subplot
    viewport_subplot = gr_viewport_from_bbox(bbox(sp), w, h, viewport_canvas)
    viewport_plotarea[:] = gr_viewport_from_bbox(plotarea(sp), w, h, viewport_canvas)

    # fill in the plot area background
    bg = getColor(sp[:background_color_inside])
    gr_fill_viewport(viewport_plotarea, bg)

    # reduced from before... set some flags based on the series in this subplot
    # TODO: can these be generic flags?
    outside_ticks = false
    cmap = false
    draw_axes = true
    # axes_2d = true
    for series in series_list(sp)
        st = series.d[:seriestype]
        if st in (:contour, :surface, :heatmap) || series.d[:marker_z] != nothing
            cmap = true
        end
        if st == :pie
            draw_axes = false
        end
        if st == :heatmap
            outside_ticks = true
        end
    end

    if cmap && sp[:colorbar] != :none
        # note: add extra midpadding on the right for the colorbar
        viewport_plotarea[2] -= 0.1
    end

    # set our plot area view
    gr_set_viewport_plotarea()

    # these are the Axis objects, which hold scale, lims, etc
    xaxis = sp[:xaxis]
    yaxis = sp[:yaxis]
    zaxis = sp[:zaxis]

    # get data limits and set the scale flags and window
    data_lims = gr_xy_axislims(sp)
    xmin, xmax, ymin, ymax = data_lims
    scale = 0
    xtick, ytick = 1, 1
    if xmax > xmin && ymax > ymin
        # NOTE: for log axes, the major_x and major_y - if non-zero (omit labels) - control the minor grid lines (1 = draw 9 minor grid lines, 2 = no minor grid lines)
        # NOTE: for log axes, the x_tick and y_tick - if non-zero (omit axes) - only affect the output appearance (1 = nomal, 2 = scientiic notation)
        xaxis[:scale] == :log10 && (scale |= GR.OPTION_X_LOG)
        yaxis[:scale] == :log10 && (scale |= GR.OPTION_Y_LOG)
        xaxis[:flip]            && (scale |= GR.OPTION_FLIP_X)
        yaxis[:flip]            && (scale |= GR.OPTION_FLIP_Y)
        if scale & GR.OPTION_X_LOG == 0
            majorx = 1 #5
            xtick = GR.tick(xmin, xmax) / majorx
        else
            # log axis
            xtick = 2  # scientific notation
            majorx = 2 # no minor grid lines
        end
        if scale & GR.OPTION_Y_LOG == 0
            majory = 1 #5
            ytick = GR.tick(ymin, ymax) / majory
        else
            # log axis
            ytick = 2  # scientific notation
            majory = 2 # no minor grid lines
        end

        # NOTE: setwindow sets the "data coordinate" limits of the current "viewport"
        GR.setwindow(xmin, xmax, ymin, ymax)
        GR.setscale(scale)
    end

    # draw the axes
    gr_set_font(xaxis[:tickfont])
    gr_set_textcolor(xaxis[:foreground_color_text])
    GR.setlinewidth(1)

    if is3d(sp)
        zmin, zmax = gr_lims(zaxis, true)
        GR.setspace(zmin, zmax, 40, 70)
        xtick = GR.tick(xmin, xmax) / 2
        ytick = GR.tick(ymin, ymax) / 2
        ztick = GR.tick(zmin, zmax) / 2
        ticksize = 0.01 * (viewport_plotarea[2] - viewport_plotarea[1])

        # GR.setlinetype(GR.LINETYPE_DOTTED)
        if sp[:grid]
            GR.grid3d(xtick, 0, ztick, xmin, ymin, zmin, 2, 0, 2)
            GR.grid3d(0, ytick, 0, xmax, ymin, zmin, 0, 2, 0)
        end
        GR.axes3d(xtick, 0, ztick, xmin, ymin, zmin, 2, 0, 2, -ticksize)
        GR.axes3d(0, ytick, 0, xmax, ymin, zmin, 0, 2, 0, ticksize)

    elseif ispolar(sp)
        r = gr_set_viewport_polar()
        rmin, rmax = GR.adjustrange(minimum(r), maximum(r))
        gr_polaraxes(rmin, rmax)

    elseif draw_axes
        # draw the grid lines
        # TODO: control line style/width
        # GR.setlinetype(GR.LINETYPE_DOTTED)
        if sp[:grid]
            gr_set_linecolor(sp[:foreground_color_grid])
            GR.grid(xtick, ytick, 0, 0, majorx, majory)
        end

        window_diag = sqrt(gr_view_xdiff()^2 + gr_view_ydiff()^2)
        ticksize = 0.0075 * window_diag
        if outside_ticks
            ticksize = -ticksize
        end
        # TODO: this should be done for each axis separately
        gr_set_linecolor(xaxis[:foreground_color_axis])

        x1, x2 = xaxis[:flip] ? (xmax,xmin) : (xmin,xmax)
        y1, y2 = yaxis[:flip] ? (ymax,ymin) : (ymin,ymax)
        GR.axes(xtick, ytick, x1, y1, 1, 1, ticksize)
        GR.axes(xtick, ytick, x2, y2, -1, -1, -ticksize)
    end
    # end

    # add the guides
    GR.savestate()
    if sp[:title] != ""
        gr_set_font(sp[:titlefont])
        GR.settextalign(GR.TEXT_HALIGN_CENTER, GR.TEXT_VALIGN_TOP)
        gr_set_textcolor(sp[:foreground_color_title])
        gr_text(gr_view_xcenter(), viewport_subplot[4], sp[:title])
    end

    if xaxis[:guide] != ""
        gr_set_font(xaxis[:guidefont])
        GR.settextalign(GR.TEXT_HALIGN_CENTER, GR.TEXT_VALIGN_BOTTOM)
        gr_set_textcolor(xaxis[:foreground_color_guide])
        gr_text(gr_view_xcenter(), viewport_subplot[3], xaxis[:guide])
    end

    if yaxis[:guide] != ""
        gr_set_font(yaxis[:guidefont])
        GR.settextalign(GR.TEXT_HALIGN_CENTER, GR.TEXT_VALIGN_TOP)
        GR.setcharup(-1, 0)
        gr_set_textcolor(yaxis[:foreground_color_guide])
        gr_text(viewport_subplot[1], gr_view_ycenter(), yaxis[:guide])
    end
    GR.restorestate()

    # TODO: can we remove?
    gr_set_font(xaxis[:tickfont])
    GR.setcolormap(1000 + GR.COLORMAP_COOLWARM)

    for (idx, series) in enumerate(series_list(sp))
        d = series.d
        st = d[:seriestype]

        # update the current stored gradient
        if st in (:contour, :surface, :wireframe, :heatmap)
            gr_set_gradient(d[:fillcolor], d[:fillalpha])
        elseif d[:marker_z] != nothing
            d[:markercolor] = gr_set_gradient(d[:markercolor], d[:markeralpha])
        end

        GR.savestate()

        # update the bounding window
        if ispolar(sp)
            gr_set_viewport_polar()
        else
            xmin, xmax, ymin, ymax = data_lims
            if xmax > xmin && ymax > ymin
                GR.setwindow(xmin, xmax, ymin, ymax)
            end
        end

        x, y, z = d[:x], d[:y], d[:z]
        frng = d[:fillrange]

        # recompute data
        if st in (:contour, :surface, :wireframe)
            z = vec(transpose_z(d, z.surf, false))
        elseif ispolar(sp)
            if frng != nothing
                _, frng = convert_to_polar(x, frng, (rmin, rmax))
            end
            x, y = convert_to_polar(x, y, (rmin, rmax))
        end

        if st in (:path, :scatter)
            if length(x) > 1

                # do area fill
                if frng != nothing
                    gr_set_fillcolor(d[:fillcolor], d[:fillalpha])
                    GR.setfillintstyle(GR.INTSTYLE_SOLID)
                    frng = isa(frng, Number) ? Float64[frng] : frng
                    nx, ny, nf = length(x), length(y), length(frng)
                    n = max(nx, ny)
                    fx, fy = zeros(2n), zeros(2n)
                    for i=1:n
                        fx[i] = fx[end-i+1] = cycle(x,i)
                        fy[i] = cycle(y,i)
                        fy[end-i+1] = cycle(frng,i)
                    end
                    GR.fillarea(fx, fy)
                end

                # draw the line(s)
                if st == :path
                    gr_set_line(d[:linewidth], d[:linestyle], d[:linecolor], d[:linealpha])
                    gr_polyline(x, y)
                end
            end

            if d[:markershape] != :none
                gr_draw_markers(series, x, y)
            end

        elseif st == :contour
            zmin, zmax = gr_lims(zaxis, false)
            if typeof(d[:levels]) <: Array
                h = d[:levels]
            else
                h = linspace(zmin, zmax, d[:levels])
            end
            GR.setspace(zmin, zmax, 0, 90)
            if d[:fillrange] != nothing
                GR.surface(x, y, z, GR.OPTION_CELL_ARRAY)
            else
                GR.contour(x, y, h, z, 1000)
            end
            
            # create the colorbar of contour levels
            if sp[:colorbar] != :none
                gr_set_viewport_cmap(sp)
                l = round(Int32, 1000 + (h - minimum(h)) / (maximum(h) - minimum(h)) * 255)
                GR.setwindow(xmin, xmax, zmin, zmax)
                GR.cellarray(xmin, xmax, zmax, zmin, 1, length(l), l)
                ztick = 0.5 * GR.tick(zmin, zmax)
                GR.axes(0, ztick, xmax, zmin, 0, 1, 0.005)
                gr_set_viewport_plotarea()
            end

        elseif st in [:surface, :wireframe]
            if st == :surface
                GR.gr3.surface(x, y, z, GR.OPTION_COLORED_MESH)
            else
                GR.setfillcolorind(0)
                GR.surface(x, y, z, GR.OPTION_FILLED_MESH)
            end
            cmap && gr_colorbar(sp)

        elseif st == :heatmap
            z = vec(transpose_z(d, z.surf, false))
            zmin, zmax = gr_lims(zaxis, true)
            GR.setspace(zmin, zmax, 0, 90)
            GR.surface(x, y, z, GR.OPTION_COLORED_MESH)
            cmap && gr_colorbar(sp)

        elseif st in (:path3d, :scatter3d)
            # draw path
            if st == :path3d
                if length(x) > 1
                    gr_set_line(d[:linewidth], d[:linestyle], d[:linecolor], d[:linealpha])
                    GR.polyline3d(x, y, z)
                end
            end

            # draw markers
            if st == :scatter3d || d[:markershape] != :none
                x2, y2 = unzip(map(GR.wc3towc, x, y, z))
                gr_draw_markers(series, x2, y2)
            end

        # TODO: replace with pie recipe
        elseif st == :pie
            GR.selntran(0)
            GR.setfillintstyle(GR.INTSTYLE_SOLID)
            xmin, xmax, ymin, ymax = viewport_plotarea
            ymax -= 0.05 * (xmax - xmin)
            xcenter = 0.5 * (xmin + xmax)
            ycenter = 0.5 * (ymin + ymax)
            if xmax - xmin > ymax - ymin
                r = 0.5 * (ymax - ymin)
                xmin, xmax = xcenter - r, xcenter + r
            else
                r = 0.5 * (xmax - xmin)
                ymin, ymax = ycenter - r, ycenter + r
            end
            labels = pie_labels(sp, series)
            slices = d[:y]
            numslices = length(slices)
            total = sum(slices)
            a1 = 0
            x = zeros(3)
            y = zeros(3)
            for i in 1:numslices
                a2 = round(Int, a1 + (slices[i] / total) * 360.0)
                GR.setfillcolorind(980 + (i-1) % 20)
                GR.fillarc(xmin, xmax, ymin, ymax, a1, a2)
                alpha = 0.5 * (a1 + a2)
                cosf = r * cos(alpha * pi / 180)
                sinf = r * sin(alpha * pi / 180)
                x[1] = xcenter + cosf
                y[1] = ycenter + sinf
                x[2] = x[1] + 0.1 * cosf
                y[2] = y[1] + 0.1 * sinf
                y[3] = y[2]
                if 90 <= alpha < 270
                    x[3] = x[2] - 0.05
                    GR.settextalign(GR.TEXT_HALIGN_RIGHT, GR.TEXT_VALIGN_HALF)
                    gr_text(x[3] - 0.01, y[3], string(labels[i]))
                else
                    x[3] = x[2] + 0.05
                    GR.settextalign(GR.TEXT_HALIGN_LEFT, GR.TEXT_VALIGN_HALF)
                    gr_text(x[3] + 0.01, y[3], string(labels[i]))
                end
                gr_polyline(x, y)
                a1 = a2
            end
            GR.selntran(1)

        elseif st == :shape
            # draw the interior
            gr_set_fill(d[:fillcolor], d[:fillalpha])
            gr_polyline(d[:x], d[:y], GR.fillarea)

            # draw the shapes
            gr_set_line(d[:linewidth], :solid, d[:linecolor], d[:linealpha])
            gr_polyline(d[:x], d[:y])


        elseif st == :image
            img = d[:z].surf
            w, h = size(img)
            if eltype(img) <: Colors.AbstractGray
                grey = round(UInt8, float(img) * 255)
                rgba = map(c -> UInt32( 0xff000000 + Int(c)<<16 + Int(c)<<8 + Int(c) ), grey)
            else
                rgba = map(c -> UInt32( round(Int, alpha(c) * 255) << 24 +
                                        round(Int,  blue(c) * 255) << 16 +
                                        round(Int, green(c) * 255) << 8  +
                                        round(Int,   red(c) * 255) ), img)
            end
            GR.drawimage(xmin, xmax, ymax, ymin, w, h, rgba)
        end

        GR.restorestate()
    end


    # add the legend
    if sp[:legend] != :none
        GR.savestate()
        GR.selntran(0)
        GR.setscale(0)
        gr_set_font(sp[:legendfont])
        w = 0
        i = 0
        n = 0
        for series in series_list(sp)
            should_add_to_legend(series) || continue
            n += 1
            if typeof(series.d[:label]) <: Array
                i += 1
                lab = series.d[:label][i]
            else
                lab = series.d[:label]
            end
            tbx, tby = gr_inqtext(0, 0, lab)
            w = max(w, tbx[3] - tbx[1])
        end
        if w > 0
            xpos = viewport_plotarea[2] - 0.05 - w
            ypos = viewport_plotarea[4] - 0.06
            dy = _gr_point_mult[1] * sp[:legendfont].pointsize * 1.75
            GR.setfillintstyle(GR.INTSTYLE_SOLID)
            gr_set_fillcolor(sp[:background_color_legend])
            GR.fillrect(xpos - 0.08, xpos + w + 0.02, ypos + dy, ypos - dy * n)
            GR.setlinetype(1)
            GR.setlinewidth(1)
            GR.drawrect(xpos - 0.08, xpos + w + 0.02, ypos + dy, ypos - dy * n)
            i = 0
            for series in series_list(sp)
                should_add_to_legend(series) || continue
                d = series.d
                st = d[:seriestype]
                gr_set_line(d[:linewidth], d[:linestyle], d[:linecolor], d[:linealpha])
                if st == :path
                    GR.polyline([xpos - 0.07, xpos - 0.01], [ypos, ypos])
                elseif st == :shape
                    gr_set_fill(d[:fillcolor], d[:fillalpha])
                    l, r = xpos-0.07, xpos-0.01
                    b, t = ypos-0.4dy, ypos+0.4dy
                    x = [l, r, r, l, l]
                    y = [b, b, t, t, b]
                    gr_polyline(x, y, GR.fillarea)
                    gr_polyline(x, y)
                end

                gr_draw_markers(d, xpos-[0.06,0.02], [ypos,ypos], 10, nothing)
                # shape = d[:markershape]
                # if shape != :none #st == :scatter || d[:markershape] != :none
                #     msize = 10
                #     for xoff in [0.06,0.02]
                #         gr_set_markercolor(d[:markerstrokecolor], d[:markerstrokealpha])
                #         gr_draw_marker(xpos-xoff, ypos, msize*1.1, shape)
                #         gr_set_markercolor(d[:markercolor], d[:markeralpha])
                #         gr_draw_marker(xpos-xoff, ypos, msize, shape)
                #     end
                #     # gr_setmarkershape(d)
                #     # if st == :path
                #     #     gr_polymarker(d, [xpos - 0.06, xpos - 0.02], [ypos, ypos])
                #     # else
                #     #     gr_polymarker(d, [xpos - 0.06, xpos - 0.04, xpos - 0.02], [ypos, ypos, ypos])
                #     # end
                # end
                if typeof(d[:label]) <: Array
                    i += 1
                    lab = d[:label][i]
                else
                    lab = d[:label]
                end
                GR.settextalign(GR.TEXT_HALIGN_LEFT, GR.TEXT_VALIGN_HALF)
                gr_set_textcolor(sp[:foreground_color_legend])
                gr_text(xpos, ypos, lab)
                ypos -= dy
            end
        end
        GR.selntran(1)
        GR.restorestate()
    end

    # add annotations
    GR.savestate()
    for ann in sp[:annotations]
        x, y, val = ann
        x, y = GR.wctondc(x, y)
        gr_set_font(val.font)
        gr_text(x, y, val.str)
    end
    GR.restorestate()
end


# ----------------------------------------------------------------

const _gr_mimeformats = Dict(
    "application/pdf"         => "pdf",
    "image/png"               => "png",
    "application/postscript"  => "ps",
    "image/svg+xml"           => "svg",
)


for (mime, fmt) in _gr_mimeformats
    @eval function _writemime(io::IO, ::MIME{Symbol($mime)}, plt::Plot{GRBackend})
        GR.emergencyclosegks()
        wstype = haskey(ENV, "GKS_WSTYPE") ? ENV["GKS_WSTYPE"] : "0"
        filepath = tempname() * "." * $fmt
        ENV["GKS_WSTYPE"] = $fmt
        ENV["GKS_FILEPATH"] = filepath
        gr_display(plt)
        GR.emergencyclosegks()
        write(io, readall(filepath))
        ENV["GKS_WSTYPE"] = wstype
        rm(filepath)
    end
end

function _display(plt::Plot{GRBackend})
    if plt[:display_type] == :inline
        GR.emergencyclosegks()
        filepath = tempname() * ".pdf"
        ENV["GKS_WSTYPE"] = "pdf"
        ENV["GKS_FILEPATH"] = filepath
        gr_display(plt)
        GR.emergencyclosegks()
        content = string("\033]1337;File=inline=1;preserveAspectRatio=0:", base64encode(open(readbytes, filepath)), "\a")
        println(content)
        rm(filepath)
    else
        gr_display(plt)
    end
end
