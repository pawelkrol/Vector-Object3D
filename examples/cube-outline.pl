#!/usr/bin/perl

use strict;
use warnings;

use Readonly;
use Term::ProgressBar 2.00;
use Tk;
use Vector::Object3D::Point;
use Vector::Object3D::Polygon;

Readonly our $draw_scale => 3;
Readonly our $height => $draw_scale * 128;
Readonly our $width => $draw_scale * 128;
Readonly our $fps => 50;
Readonly our $num_frames => 256;
Readonly our $pi => 3.14159;
Readonly our $push_away => 50;
Readonly our $distance => 200;
Readonly our $scale => 9;

my @polygon = setup_object_polygons();

my @precalculated_data;

for (my $i = 0; $i < @polygon; $i++) {
    printf "[POLYGON %d/%d]\n", $i + 1, scalar @polygon;
    push @precalculated_data, calculate_polygon_frames($polygon[$i]);
}

my $mw = MainWindow->new;
our $canvas = $mw->Canvas(
    -width => $width,
    -height => $height,
    -background => '#CCCCCC'
)->pack;

draw_object(0);
MainLoop;

sub setup_object_polygons {
    my $point = [
        [-1, -1, +1],
        [-1, +1, +1],
        [+1, +1, +1],
        [+1, -1, +1],
        [-1, -1, -1],
        [-1, +1, -1],
        [+1, +1, -1],
        [+1, -1, -1],
    ];

    my $vertex1 = Vector::Object3D::Point->new(coord => [$point->[0][0], $point->[0][1], $point->[0][2]]);
    my $vertex2 = Vector::Object3D::Point->new(coord => [$point->[1][0], $point->[1][1], $point->[1][2]]);
    my $vertex3 = Vector::Object3D::Point->new(coord => [$point->[2][0], $point->[2][1], $point->[2][2]]);
    my $vertex4 = Vector::Object3D::Point->new(coord => [$point->[3][0], $point->[3][1], $point->[3][2]]);

    my $vertex5 = Vector::Object3D::Point->new(coord => [$point->[4][0], $point->[4][1], $point->[4][2]]);
    my $vertex6 = Vector::Object3D::Point->new(coord => [$point->[5][0], $point->[5][1], $point->[5][2]]);
    my $vertex7 = Vector::Object3D::Point->new(coord => [$point->[6][0], $point->[6][1], $point->[6][2]]);
    my $vertex8 = Vector::Object3D::Point->new(coord => [$point->[7][0], $point->[7][1], $point->[7][2]]);

    my @vertices = (
        [$vertex1, $vertex2, $vertex3, $vertex4],
        [$vertex5, $vertex8, $vertex7, $vertex6],
        [$vertex1, $vertex5, $vertex6, $vertex2],
        [$vertex2, $vertex6, $vertex7, $vertex3],
        [$vertex3, $vertex7, $vertex8, $vertex4],
        [$vertex4, $vertex8, $vertex5, $vertex1],
    );

    return map { Vector::Object3D::Polygon->new(vertices => $_) } @vertices;
}

sub calculate_polygon_frames {
    my ($polygon) = @_;

    my %rotation = (
        rotation_xy => -2 * $pi / $num_frames,
        rotation_xz => +4 * $pi / $num_frames,
        rotation_yz => +2 * $pi / $num_frames,
    );

    my $observer = Vector::Object3D::Point->new(x => 0, y => 0, z => 0);

    my $progress = Term::ProgressBar->new({
        name  => 'Calculating',
        count => $num_frames,
    });

    my @frame;

    for (my $i = 0; $i < $num_frames; $i++) {
        my %current_step_rotation = map { $_ => $i * $rotation{$_} } keys %rotation;

        my $rotated_polygon = calculate_rotated_frame($polygon, \%current_step_rotation);

        my $is_plane_visible = $rotated_polygon->is_plane_visible(observer => $observer);

        if ($is_plane_visible) {
            my @vertices = get_polygon_vertices($rotated_polygon);

            $frame[$i] = \@vertices;
        }

        $progress->update($i);
    }

    $progress->update($num_frames);

    return \@frame;
}

sub calculate_rotated_frame {
    my ($polygon, $rotation) = @_;

    $polygon = $polygon->rotate(rotate_xy => 0, rotate_yz => 0, rotate_xz => $rotation->{rotation_xz});
    $polygon = $polygon->rotate(rotate_xy => 0, rotate_yz => $rotation->{rotation_yz}, rotate_xz => 0);
    $polygon = $polygon->rotate(rotate_xy => $rotation->{rotation_xy}, rotate_yz => 0, rotate_xz => 0);

    $polygon = $polygon->scale(scale_x => $scale, scale_y => $scale, scale_z => $scale);

    $polygon = $polygon->translate(shift_x => 0, shift_y => 0, shift_z => $push_away);

    return $polygon;
}

sub get_polygon_vertices {
    my ($polygon) = @_;

    my $casted_polygon = $polygon->cast(type => 'perspective', distance => $distance);
    my $translated_polygon = $casted_polygon->translate(shift_x => $width / 6, shift_y => $height / 6);

    my @vertices = $translated_polygon->get_vertices;

    return map { $draw_scale * int $_ } map { $_->get_xy } @vertices;
}

sub draw_object {
    my ($step) = @_;

    $canvas->delete('polygon' . $_) for (0 .. @precalculated_data);

    for (my $i = 0; $i < @precalculated_data; $i++) {
        my $polygon = $precalculated_data[$i];

        my $data = $polygon->[$step];
        next unless defined $data;

        $canvas->createPolygon(@{$data}, -fill => undef, -outline => '#002200', -width => 5, -tags => 'polygon' . $i);
    }

    $step = 0 if ++$step == $num_frames;

    $mw->after(1000 / $fps => sub { draw_object($step) });

    return;
}
