#!/usr/bin/ruby


TAU=Math::PI*2

class Arc
  attr_reader :centre, :radius, :range

  def initialize(centre=Point[0,0,0], radius=1, range=0..1)
    @centre=centre
    @radius=radius
    @range=range
  end

  def absolute_parameter(t)
    range.first+t*(range.last-range.first)
  end
  
  def point(t)
    real_t=TAU*absolute_parameter(t)
    
    Point.new(
      radius*Math::cos(real_t)+centre.x,
      radius*Math::sin(real_t)+centre.y,
      centre.z
    )
  end
end

class Segment
  attr_reader :first, :last
  
  def initialize(first, last)
    @first=first
    @last=last
  end
  
  def point(t)
    Point.new(
      last.x*t+first.x*(1-t),
      last.y*t+first.y*(1-t),
      last.z*t+first.z*(1-t))
  end

end

class StandardCrossSection
  attr_reader :height, :width, :broadside_radius, :turn_radius
  
  def initialize(height, width, broadside_radius, turn_radius)
    @height=height
    @width=width
    @broadside_radius=broadside_radius
    @turn_radius=turn_radius
  end

  def broadside_arc
    build_arcs if @broadside_arc.nil?
    @broadside_arc
  end
  
  def turn_arc
    build_arcs if @turn_arc.nil?
    @turn_arc
  end

  def flat
    first=turn_arc.point(1)
    last=Point.new(0,height/2, 0)
    Segment.new(first, last)
  end
  
  private
  def build_arcs
    centre_y=height/2-turn_radius
    x_from_broadside_centre=Math::sqrt((broadside_radius-turn_radius)**2-centre_y**2)
    centre_x=x_from_broadside_centre+width/2-broadside_radius
    start_turn=Math.atan2(centre_y, x_from_broadside_centre)/TAU # Angle is the same as that of the turn itself
    end_turn=0.25
    @turn_arc=Arc.new(Point.new(centre_x, centre_y, 0), turn_radius, start_turn..end_turn)
    turn_start_point=@turn_arc.point(0)
    broadside_end=Math.atan2(turn_start_point.y, turn_start_point.x-(width/2-broadside_radius))/TAU
    @broadside_arc=Arc.new(Point.new(width/2-broadside_radius, 0, 0), broadside_radius, 0..broadside_end)
  end

  
end

class Point
  attr_reader :x,:y,:z
  def initialize(x,y,z)
    @x=x
    @y=y
    @z=z
  end
end

def svg
  puts <<EOS
<svg xmlns="http://www.w3.org/2000/svg" version="1.1">
EOS
  
  yield

  puts <<EOS
</svg>
EOS
end

def polyline(points)
  points_string = points.map{|p| "#{p.x},#{p.y}"}.join(" ")
  puts "<polyline points='#{points_string}' style='fill:none;stroke:black;stroke-width:0.1' />"
end

svg do
  points = []
  section=StandardCrossSection.new(25, 43, 13, 5.75)

  barc=section.broadside_arc
  polyline 21.times.map { |i| barc.point(i/20.0) }

  tarc=section.turn_arc
  polyline 21.times.map { |i| tarc.point(i/20.0) }

  flat=section.flat
  polyline 21.times.map { |i| flat.point(i/20.0) }

end
