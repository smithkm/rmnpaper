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
    point_absolute(absolute_parameter(t))
  end

  def point_absolute(t)
    Point.new(
      radius*Math::cos(TAU*t)+centre.x,
      radius*Math::sin(TAU*t)+centre.y,
      centre.z
    )
  end
  
  def include?(theta)
    range.include?(theta/TAU)
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

  def mirror(axis)
    Segment.new(first.mirror(axis), last.mirror(axis))
  end
end

class StandardCrossSection
  attr_reader :height, :width, :broadside_radius, :turn_radius, :z
  
  def initialize(height, width, broadside_radius, turn_radius, z=0)
    @height=height
    @width=width
    @broadside_radius=broadside_radius
    @turn_radius=turn_radius
    @z=z
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
    last=Point.new(0,height/2, z)
    Segment.new(first, last)
  end

  def copy_at(new_z)
    StandardCrossSection.new(height, width, broadside_radius, turn_radius, new_z)
  end

  def point_for_param(t)
    return broadside_arc.point_absolute t/4 if(broadside_arc.range.include? t/4)
    return turn_arc.point_absolute t/4
  end
  
  private
  def build_arcs
    centre_y=height/2-turn_radius
    x_from_broadside_centre=Math::sqrt((broadside_radius-turn_radius)**2-centre_y**2)
    centre_x=x_from_broadside_centre+width/2-broadside_radius
    start_turn=Math.atan2(centre_y, x_from_broadside_centre)/TAU # Angle is the same as that of the turn itself
    end_turn=0.25
    @turn_arc=Arc.new(Point.new(centre_x, centre_y, z), turn_radius, start_turn...end_turn)
    turn_start_point=@turn_arc.point(0)
    broadside_end=Math.atan2(turn_start_point.y, turn_start_point.x-(width/2-broadside_radius))/TAU
    @broadside_arc=Arc.new(Point.new(width/2-broadside_radius, 0, z), broadside_radius, 0...broadside_end)
  end
  
end

class TaperEndCrossSection
  attr_reader :radius, :theta, :z
  attr_reader :broadside_arc, :turn_arc, :flat

  def initialize(radius, theta, z=0)
    @radius=radius
    @theta=theta
    @z=z

    @broadside_arc=Arc.new(Point.new(0,0,z), radius, 0..(theta/TAU))
    @turn_arc=Arc.new(Point.new(0,0,z), radius, (theta/TAU)..0.25)
    @flat=Segment.new(Point.new(0,radius, z), Point.new(0,radius, z))
  end

  def copy_at(new_z)
    TaperEndCrossSection.new(radius, theta, new_z)
  end

  def point_for_param(t)
    Point.new(
      radius*Math::cos(TAU/4*t),
      radius*Math::sin(TAU/4*t),
      z
    )
  end

end

class FlareStartCrossSection
  attr_reader :radius, :theta1, :theta2, :z
  attr_reader :broadside_arc, :turn_arc, :flat

  def initialize(radius, theta1, theta2, z=0)
    @radius=radius
    @theta1=theta1
    @theta2=theta2
    @z=z

    @broadside_arc=Arc.new(Point.new(0,0,z), radius, 0..(theta1/TAU))
    @turn_arc=Arc.new(Point.new(0,0,z), radius, (theta1/TAU)..(theta2/TAU))
    @flat=Arc.new(Point.new(0,0,z), radius, (theta2/TAU)..0.25)
  end

  def copy_at(new_z)
    FlareStartCrossSection.new(radius, theta1, theta2, new_z)
  end
  
  def point_for_param(t)
    Point.new(
      radius*Math::cos(TAU/4*t),
      radius*Math::sin(TAU/4*t),
      z
    )
  end
end

class Point
  attr_reader :x,:y,:z
  def initialize(x,y,z)
    @x=x
    @y=y
    @z=z
  end

  def to_vec
    Vector[x,y,z]
  end

  def mirror(axis)
    case axis
    when :x
      Point.new(-x,y,z)
    when :y
      Point.new(x,-y,z)
    when :z
      Point.new(x,y,-z)
    else
      raise "Not a valid axis #{axis}"
    end
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


def strip(section1, section2, n, verts, polys)
  segments=
    (n+1).times.map { |i| Segment.new(section1.point_for_param(i.to_f/n), section2.point_for_param(i.to_f/n)) }

  if(segments[-1].first.x!=0.0 and segments[-1].last.x!=0.0)
    segments<< Segment.new(
      Point.new(0, segments[-1].first.y, segments[-1].first.z),
      Point.new(0, segments[-1].last.y, segments[-1].last.z)
    )
  end
  segments.reverse!
  segments+=segments.reverse.map {|segment| segment.mirror :y}
  
  segments.map! do |segment|
    
    verts << segment.first
    i_first = verts.size
    verts << segment.last
    i_last = verts.size
    [i_first, i_last]
  end

  segments.each_cons(2) do |base, extent|
    polys << [base[0], base[1], extent[1], extent[0]]
  end
end

def double_strip(section1, section2, n, verts, polys, p1, p2)
  base_segments= (n+1).times.map { |i| Segment.new(section1.point_for_param(i.to_f/n), section2.point_for_param(i.to_f/n)) }
  if(base_segments[-1].first.x!=0.0 and base_segments[-1].last.x!=0.0)
    base_segments<< Segment.new(
      Point.new(0, base_segments[-1].first.y, base_segments[-1].first.z),
      Point.new(0, base_segments[-1].last.y, base_segments[-1].last.z)
    )
  end
  base_segments.reverse!
  base_segments+=base_segments.reverse.map {|segment| segment.mirror :y}
  segments1=[]
  segments2=[]
  base_segments.map do |base|
    avg_point=base.point(p1)
    final_point=Point.new(avg_point.x, avg_point.y, base.point(p2).z)
    segments1<< Segment.new(base.first, final_point)
    segments2<< Segment.new(final_point, base.last)
  end
  [segments1,segments2].each do |segments|
    mapped_segments = segments.map do |segment|
      
      verts << segment.first
      i_first = verts.size
      verts << segment.last
      i_last = verts.size
      [i_first, i_last]
    end
    
    mapped_segments.each_cons(2) do |base, extent|
      polys << [base[0], base[1], extent[1], extent[0]]
    end
  end
end

def orthonormal(p1, p2, p3)
  u1 = p2.to_vec - p1.to_vec
  v1 = p3.to_vec - p2.to_vec

  u2 = u1.normalize
  v2 = v1-u2*(v1.inner_product u2)
  w2 = u2.cross_product v2
end

def flat_strip(section1, section2, n)
  segments=
    (n.times.map { |i| Segment.new(section1.broadside_arc.point(i.to_f/n), section2.broadside_arc.point(i.to_f/n)) } +
     n.times.map { |i| Segment.new(section1.turn_arc.point(i.to_f/n), section2.turn_arc.point(i.to_f/n)) } +
     (n+1).times.map { |i| Segment.new(section1.flat.point(i.to_f/n), section2.flat.point(i.to_f/n)) }).map do |segment|
    
    [segment.first.to_nvec, segment.last.to_nvec]
  end
  
  base_line = [Vector[0,0,0], Vector[segments[0],0,0]]
  
  segments.each_cons(2) do |base, extent|
#    polys << [base[0], base[1], extent[1], extent[0]]
    polys << [base[0], base[1], extent[1]]
    polys << [base[0], extent[1], extent[0]]
  end

end

def obj
  verts=[]
  polys=[]
  yield verts, polys

  n=0
  flips=[[1,1,1],[1,-1,1], [-1,-1,1],[-1,1,1]]
  flips=[[1,1,1]]
  flips.each do |flip|
    verts.each do |vert|
      puts "v #{vert.x*flip[0]} #{vert.y*flip[1]} #{vert.z*flip[2]}"
    end
    polys.each do |poly|
      p=poly
      p=poly.reverse if(flip.reduce(:*)<0)
      puts "f "+poly.map{|i| i+n}.join(" ")
    end
    n+=verts.size
  end
end

# Chanson

#draft=25
#beam=43
#radius_broadside=13
#radius_turn=5.75
#radius_taper=8.65
#forward_taper_length=75.5
#aft_taper_length=82.5
#centre_length=138
#imp_length=5
#flare_length=5.25
#forward_hammer_flat_length=9
#forward_hammer_taper_length=20
#forward_hammer_draft=12
#forward_hammer_beam=26.9
#forward_hammer_radius=6.05

#aft_hammer_flat_length=13
#aft_hammer_taper_length=9
#aft_hammer_draft=forward_hammer_draft
#aft_hammer_beam=forward_hammer_beam
#aft_hammer_radius=forward_hammer_radius


#flare_p1 = 0.25
#flare_p2 = 0.65



# Wolfhound

draft=29
beam=51
radius_broadside=15
radius_turn=5.75
radius_taper=10.25
forward_taper_length=88.25
aft_taper_length=81
centre_length=170
imp_length=4.5
imp_radius=11
imp_bevel=0.5
flare_length=4.5
forward_hammer_flat_length=18.5
forward_hammer_taper_length=27.5
forward_hammer_draft=18
forward_hammer_beam=30
forward_hammer_radius=9.25

aft_hammer_flat_length=23.75
aft_hammer_taper_length=14.25
aft_hammer_draft=forward_hammer_draft
aft_hammer_beam=forward_hammer_beam
aft_hammer_radius=forward_hammer_radius


flare_p1 = 0.25
flare_p2 = 0.65


# Segments per patch

n=10

if true
  z=-428/2

  full_cs = StandardCrossSection.new(draft, beam, radius_broadside, radius_turn)

  full_turn_arc = full_cs.turn_arc

  theta1 = Math::atan2(full_turn_arc.point(0).y, full_turn_arc.point(0).x)
  theta2 = Math::atan2(full_turn_arc.point(1).y, full_turn_arc.point(1).x)
 
  taper_cs = TaperEndCrossSection.new(radius_taper, (0.25*TAU-(theta2-theta1)+theta1)/2)
  flare_cs =  FlareStartCrossSection.new(radius_taper, theta1, theta2)
  nose_cs = StandardCrossSection.new(forward_hammer_draft, forward_hammer_beam, forward_hammer_radius, radius_turn)
  tail_cs = StandardCrossSection.new(aft_hammer_draft, aft_hammer_beam, aft_hammer_radius, radius_turn)
  impeller_cs = FlareStartCrossSection.new(imp_radius, theta1, theta2)
  nil_cs = FlareStartCrossSection.new(0, theta1, theta2)
  
  obj do |verts, polys|

    [#nil_cs.copy_at(z),
     tail_cs.copy_at(z),
     full_cs.copy_at(z+=aft_hammer_taper_length),
     full_cs.copy_at(z+=aft_hammer_flat_length),
     flare_cs.copy_at(z+=flare_length)
    ].each_cons(2) do |section1, section2|
      $stderr.puts [section1.inspect, section2.inspect].inspect
      if(FlareStartCrossSection===section1 || FlareStartCrossSection===section2)
        double_strip(section1, section2, n, verts, polys, flare_p1,flare_p2)
      else
        strip(section1, section2, n, verts, polys)
      end
    end

    [flare_cs.copy_at(z),
     impeller_cs.copy_at(z+=imp_bevel),
     impeller_cs.copy_at(z+=imp_length-imp_bevel*2),
     flare_cs.copy_at(z+=imp_bevel)
    ].each_cons(2) do |section1, section2|
      strip(section1, section2, n, verts, polys)
    end
    
    [taper_cs.copy_at(z),
     full_cs.copy_at(z+=aft_taper_length),
     full_cs.copy_at(z+=centre_length),
     taper_cs.copy_at(z+=forward_taper_length)
    ].each_cons(2) do |section1, section2|
      strip(section1, section2, n, verts, polys)
    end
    
    [flare_cs.copy_at(z),
     impeller_cs.copy_at(z+=imp_bevel),
     impeller_cs.copy_at(z+=imp_length-imp_bevel*2),
     flare_cs.copy_at(z+=imp_bevel)
    ].each_cons(2) do |section1, section2|
      strip(section1, section2, n, verts, polys)
    end
    
    [flare_cs.copy_at(z),
     full_cs.copy_at(z+=flare_length),
     full_cs.copy_at(z+=forward_hammer_flat_length),
     nose_cs.copy_at(z+=forward_hammer_taper_length)#,
     #nil_cs.copy_at(z)
    ].each_cons(2) do |section1, section2|
      if(FlareStartCrossSection===section1 || FlareStartCrossSection===section2)
        double_strip(section1, section2, n, verts, polys, 1-flare_p1, 1-flare_p2)
      else
        strip(section1, section2, n, verts, polys)
      end
    end
  end
else
  svg do
    points = []
    section1=StandardCrossSection.new(25, 43, 13, 5.75, 0)
    section2=TaperEndCrossSection.new(9.9, TAU/8, 75.5)
    
    barc1=section1.broadside_arc
    tarc1=section1.turn_arc
    flat1=section1.flat
    polyline 20.times.map { |i| barc1.point(i/20.0) } + 20.times.map { |i| tarc1.point(i/20.0) } + 21.times.map { |i| flat1.point(i/20.0) }
    
    barc2=section2.broadside_arc
    tarc2=section2.turn_arc
    flat2=section2.flat
    polyline 20.times.map { |i| barc2.point(i/20.0) } + 20.times.map { |i| tarc2.point(i/20.0) } + 21.times.map { |i| flat2.point(i/20.0) }
    
    (20.times.map { |i| Segment.new(barc1.point(i/20.0), barc2.point(i/20.0))  } + 20.times.map { |i| Segment.new(tarc1.point(i/20.0), tarc2.point(i/20.0)) } + 21.times.map { |i| Segment.new(flat1.point(i/20.0), flat2.point(i/20.0)) }).each do |l|
    polyline([l.first, l.last])
    end
    
  end
end
