#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use DDG::Test::Goodie;
use DDG::Test::Location;

zci answer_type => 'calendar_conversion';
zci is_cached   => 0;

my @g22h = (
    '22 August 2003 (Gregorian) is 23 Jumaada Thani 1424 (Hijri)',
    structured_answer => {
        input     => ['22 August 2003 (Gregorian)'],
        operation => 'Calendar conversion',
        result    => '23 Jumaada Thani 1424 (Hijri)'
    },
);
my @h23g = (
    '23 Jumaada Thani 1424 (Hijri) is 22 August 2003 (Gregorian)',
    structured_answer => {
        input     => ['23 Jumaada Thani 1424 (Hijri)'],
        operation => 'Calendar conversion',
        result    => '22 August 2003 (Gregorian)'
    },
);
my @g22j = (
    '22 August 2003 (Gregorian) is 31 Mordad 1382 (Jalali)',
    structured_answer => {
        input     => ['22 August 2003 (Gregorian)'],
        operation => 'Calendar conversion',
        result    => '31 Mordad 1382 (Jalali)'
    },
);

sub location_test {
    my ($location_code, $query, @res_params) = @_;
    my $location = test_location($location_code);
    return DDG::Request->new(
        query_raw => $query,
        location => $location
    ) => test_zci(@res_params);
}

ddg_goodie_test(
    [qw(DDG::Goodie::CalendarConversion)],
    location_test('de', '22/8/2003 to hijri', @g22h),
    location_test('de', '22/8/2003 to the hijri calendar', @g22h),
    location_test('de', '22,8,2003 to hijri', @g22h),
    location_test('de', '23/6/1424 in hijri to gregorian years', @h23g),
    location_test('de', '23/6/1424 hijri to gregorian', @h23g),
    location_test('de', '22/8/2003 to jalali', @g22j),
    location_test('de', '31/5/1382 jalali to gregorian',
        '31 Mordad 1382 (Jalali) is 22 August 2003 (Gregorian)',
        structured_answer => {
            input     => ['31 Mordad 1382 (Jalali)'],
            operation => 'Calendar conversion',
            result    => '22 August 2003 (Gregorian)'
        },
    ),
    location_test('de', '31/5/1382 jalali to hijri',
        '31 Mordad 1382 (Jalali) is 23 Jumaada Thani 1424 (Hijri)',
        structured_answer => {
            input     => ['31 Mordad 1382 (Jalali)'],
            operation => 'Calendar conversion',
            result    => '23 Jumaada Thani 1424 (Hijri)'
        },
    ),
    location_test('de', '23/6/1424 in hijri to jalali date',
        '23 Jumaada Thani 1424 (Hijri) is 31 Mordad 1382 (Jalali)',
        structured_answer => {
            input     => ['23 Jumaada Thani 1424 (Hijri)'],
            operation => 'Calendar conversion',
            result    => '31 Mordad 1382 (Jalali)',
        },
    ),
    'August 22nd, 2003 to jalali'     => test_zci(@g22j),
    '22 Aug 2003 to Hijri'            => test_zci(@g22h),
    location_test('de', '22/8/2003 in the hijri calendar', @g22h),
    '22nd Aug 2003 in jalali'         => test_zci(@g22j),
    '8-22-2003 in hijri years'        => test_zci(@g22h),
    'August 22 2003 in jalali date'   => test_zci(@g22j),
    '22nd Aug 2003 in gregorian time' => undef,
);

done_testing;
