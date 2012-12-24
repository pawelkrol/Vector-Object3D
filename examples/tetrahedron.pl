#!/usr/bin/perl

use strict;
use warnings;

package My::Vector::Object3D::Polygon;

use Moose;
extends 'Vector::Object3D::Polygon';

has colour => (
    is  => 'rw',
    isa => 'Maybe[Str]',
);

override 'copy' => sub {
    my ($self) = @_;

    my $colour = $self->colour;
    my $copy = $self->super();
    $copy->colour($colour);

    return $copy;
};

package main;

use Readonly;
use Term::ProgressBar 2.00;
use Tk;
use Vector::Object3D;

Readonly our $distance => 100;
Readonly our $fps => 100;
Readonly our $height => 480;
Readonly our $num_frames => 360;
Readonly our $pi => 3.14159;
Readonly our $rotate_factor => 360 / $num_frames * $pi / 180;
Readonly our $scale => 50;
Readonly our $width => 640;

{
    my $current_rotation = 0;

    sub next_rotation {
        $current_rotation += $rotate_factor;

        return $current_rotation;
    }
}

my $object = define_object();
my $frames = prepare_frames();

my $mw = MainWindow->new;
my $canvas = $mw->Canvas(-width => $width, -height => $height, -background => '#AAEEAA')->pack;

draw_polygons(0);
MainLoop;

sub define_object {
    my $point1 = Vector::Object3D::Point->new(x => -3, y => 2, z => 0);
    my $point2 = Vector::Object3D::Point->new(x => 3, y => 2, z => 0);
    my $point3 = Vector::Object3D::Point->new(x => 0, y => -4, z => 0);
    my $point4 = Vector::Object3D::Point->new(x => 0, y => 0, z => 3);

    my $polygon1 = My::Vector::Object3D::Polygon->new(vertices => [$point2, $point1, $point3], colour => '#CCCC00');
    my $polygon2 = My::Vector::Object3D::Polygon->new(vertices => [$point1, $point4, $point3], colour => '#22CCCC');
    my $polygon3 = My::Vector::Object3D::Polygon->new(vertices => [$point2, $point3, $point4], colour => '#88CC22');
    my $polygon4 = My::Vector::Object3D::Polygon->new(vertices => [$point1, $point2, $point4], colour => '#22CC22');

    return Vector::Object3D->new(polygons => [$polygon1, $polygon2, $polygon3, $polygon4]);
}

sub prepare_frames {
    my @frames;

    my $progress = Term::ProgressBar->new({
        name  => 'Calculating',
        count => $num_frames,
    });

    for (my $i = 0; $i < $num_frames; $i++) {

        push @frames, setup_frame($object);

        $progress->update($i);
    }

    $progress->update($num_frames);

    return \@frames;
}

sub draw_polygons {
    my ($step) = @_;

    $step = 0 if ++$step == $num_frames;

    my @precalculated_polygons = @{ $frames->[$step] };

    $canvas->delete('polygon' . $_) for (0 .. @precalculated_polygons);

    for (my $i = 0; $i < @precalculated_polygons; $i++) {
        my $polygon = $precalculated_polygons[$i];
        my $colour = $polygon->{colour};
        my @vertices = @{ $polygon->{vertices} };
        $canvas->createPolygon(@vertices, -fill => $colour, -outline => '#002200', -width => 5, -tags => 'polygon' . $i);
    }
    $mw->after(1000 / $fps => sub { draw_polygons($step) });
}

sub setup_frame {
    my ($object) = @_;

    my $rotation = next_rotation();

    my @colours = map { $_->colour } $object->get_polygons;

    $object = $object->scale(scale_x => $scale, scale_y => $scale, scale_z => $scale);
    $object = $object->rotate(rotate_xy => 0, rotate_yz => 0, rotate_xz => $rotation);
    $object = $object->rotate(rotate_xy => -2 * $rotation, rotate_yz => 0, rotate_xz => 0);
    $object = $object->translate(shift_x => $width / 2, shift_y => $height / 2, shift_z => 0);

    my @polygons = $object->get_polygons;

    $_->colour(shift @colours) for @polygons;

    my @polygons_visible = grep { $_->is_plane_visible } @polygons;

    my @polygons_casted = map { project_polygon($_) } @polygons_visible;

    return \@polygons_casted;
}

sub project_polygon {
    my $polygon = shift;
    my @vertices = map { $_->get_xy } $polygon->cast(type => 'parallel')->get_vertices;
    return {
        colour   => $polygon->colour,
        vertices => \@vertices,
    };
}
