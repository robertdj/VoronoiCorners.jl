struct PointCollection
    OriginalPoints::Vector{GeometryBasics.Point{2,Float64}}
    EnclosingRectangle::Rectangle
    ComputationRectangle::Rectangle
    TransformedPoints::Vector{IndexablePoint2D}
end


function PointCollection(points::Vector{GeometryBasics.Point{2,Float64}}, rect)
    computation_rect = Rectangle(
        # ComputationRectangleCorners[1],
        # ComputationRectangleCorners[4],
        GeometryBasics.Point2(1.5 - 1/6, 1.5 - 1/6),
        GeometryBasics.Point2(1.5 + 1/6, 1.5 + 1/6)
    )

    transformed_points = map_rectangle(points, rect, computation_rect)

    PointCollection(points, rect, computation_rect, transformed_points)
end


function raw_tesselation(pc::PointCollection)
    n_points = length(pc.OriginalPoints)

    generators = VoronoiDelaunay.DelaunayTessellation2D{IndexablePoint2D}(n_points)
    # Note that the elements of pc.TransformedPoints are reordered by VoronoiDelaunay
    push!(generators, pc.TransformedPoints)

    voronoi_cells = Dict(1:n_points .=> [Vector{VoronoiDelaunay.Point2D}(undef, 0) for _ in 1:n_points])

    for edge in VoronoiDelaunay.voronoiedges(generators)
        # @show edge
        # @show l = clip(edge, pc.ComputationRectangle)
        l = clip(edge, pc.ComputationRectangle)
        if isnothing(l)
            continue
        end

        generator_a = VoronoiDelaunay.getgena(edge) |> getindex
        generator_b = VoronoiDelaunay.getgenb(edge) |> getindex

        push!(voronoi_cells[generator_a], geta(l))
        push!(voronoi_cells[generator_a], getb(l))

        push!(voronoi_cells[generator_b], geta(l))
        push!(voronoi_cells[generator_b], getb(l))
    end

    voronoi_cells
end


struct Tessellation
    Generators::Vector{GeometryBasics.Point{2,Float64}}
    EnclosingRectangle::Rectangle
    Cells::Vector{Vector{GeometryBasics.Point{2,Float64}}}
end


function voronoicells(pc::PointCollection)
    rt = raw_tesselation(pc)

    for corner in corners(pc.ComputationRectangle)
        nn = nearest_neighbor(corner, pc.TransformedPoints)
        for neighbor in nn
            tp_index = getindex(pc.TransformedPoints[neighbor])
            push!(rt[tp_index], corner)
        end
    end

    n_cells = length(rt)
    cells = [Vector{GeometryBasics.Point2{Float64}}(undef, 0) for _ in 1:n_cells]
    for n in 1:n_cells
        cell_corners = unique(rt[n])

        unsorted_cell_corners = map_rectangle(
            cell_corners, pc.ComputationRectangle, pc.EnclosingRectangle
        )
        cells[n] = sort(unsorted_cell_corners)
    end

    Tessellation(pc.OriginalPoints, pc.EnclosingRectangle, cells)
end


function voronoicells(points::Vector{GeometryBasics.Point{2,Float64}}, rect)
    pc = PointCollection(points, rect)
    voronoicells(pc)
end


function voronoicells(x::Vector, y::Vector, rect)
    n = length(x)
    if n != length(y)
        throw(ArgumentError("x and y must have equal length"))
    end

    points = [GeometryBasics.Point2(x[i], y[i]) for i in 1:n]
    voronoicells(points, rect)
end
