package DDG::Goodie::DateMath;
# ABSTRACT: add/subtract days/weeks/months/years to/from a date

use strict;
use DDG::Goodie;
with 'DDG::GoodieRole::Dates';
with 'DDG::GoodieRole::NumberStyler';
use DateTime::Duration;
use Lingua::EN::Numericalize;
use List::AllUtils qw(firstidx);
use DateTime::Locale;
use Try::Tiny;

triggers any => qw(second minute hour day week month year);
triggers any => qw(seconds minutes hours days weeks months years);
triggers any => qw(plus minus + -);
triggers any => qw(date time);

zci is_cached   => 0;
zci answer_type => 'date_math';


sub get_duration {
    my ($number, $unit) = @_;
    $unit = lc $unit . 's';
    my $dur = DateTime::Duration->new(
        $unit => $number,
    );
}

sub get_action_for {
    my $action = shift;
    return '+' if $action =~ /^(\+|plus|from|in|add)$/i;
    return '-' if $action =~ /^(\-|minus|ago|subtract)$/i;
}

sub should_use_clock {
    my ($unit, $form) = @_;
    return 1 if is_clock_unit($unit);
    return $form =~ /time/i if defined $form;
    return 0;
}

sub format_result {
    my ($out_date) = @_;
    my $output_date = date_output_string($out_date);
    return $output_date;
}

sub format_input {
    my ($input_date, $action, $unit, $input_number) = @_;
    my $in_date    = date_output_string($input_date);
    my $out_action = "$action $input_number $unit";
    return "$in_date $out_action";
}

my $number_re        = number_style_regex();
my $datestring_regex = datestring_regex();

my $units = qr/(?<unit>second|minute|hour|day|week|month|year)s?/i;

my $relative_regex = qr/(?<number>$number_re|[a-z\s-]+)\s+$units/i;

my $action_re = qr/(?<action>plus|add|\+|\-|minus|subtract)/i;
my $date_re   = qr/(?<date>$datestring_regex)/i;

my $operation_re = qr/$date_re(?:\s+$action_re\s+$relative_regex)?/i;
my $from_re      = qr/$relative_regex\s+(?<action>from)\s+$date_re?|(?<action>in)\s+$relative_regex/i;
my $ago_re       = qr/$relative_regex\s+(?<action>ago)/i;
my $time_24h = time_24h_regex();
my $time_12h = time_12h_regex();
my $relative_dates = relative_dates_regex();

sub build_result {
    my ($start, $action, $lang) = @_;
    my $date_locale = try { DateTime::Locale->load($lang->locale) }
        || DateTime::Locale->load('en-US');
    my @days = map {
        { display => $_, value => sprintf('%.02d', $_) }
    } (1..31);
    my @months = @{$date_locale->month_stand_alone_wide};
    my @month_hs = map { my $month = $_; {
            display => $month,
            value => sprintf('%.02d', (firstidx { $_ eq $month } @months) + 1),
        }
    } @months;
    my @modifiers = map { { display => $_ . 's', value => lc $_ } } (
        'Second', 'Minute', 'Hour', 'Day', 'Week', 'Month', 'Year',
    );
    return 'DateMath', structured_answer => {
        meta => {
            signal => 'high',
        },
        data => {
            actions => [$action],
            start_date => $start,
            date_components => [
                {
                    name => 'Month',
                    entries => \@month_hs,
                },
                {
                    name => 'Day',
                    entries => \@days,
                },
            ],
            modifiers => \@modifiers,
        },
        templates => {
            group   => 'base',
            options => {
                content => 'DDH.date_math.content',
            },
        },
    };
}

sub get_result_relative {
    my ($date, $lang) = @_;
    return unless $date =~ $relative_dates;
    $date =~ $ago_re or $date =~ $from_re;
    my $action = $+{action} or return;
    my $number = $+{number} or return;
    my $unit   = $+{unit}   or return;
    return get_result_action($action, undef, $number, $unit, $lang);
}

sub get_result_action {
    my ($action, $date, $number, $unit, $lang) = @_;
    $action = get_action_for $action or return;
    my $input_number = str2nbr($number);
    my $style = number_style_for($input_number) or return;
    my $compute_num = $style->for_computation($input_number);

    my $input_date = parse_datestring_to_date(
        defined($date) ? $date : "today") or return;

    return build_result($input_date->epoch, {
            operation => $action,
            type => $unit,
            amount => abs($compute_num),
    }, $lang);
}

handle query_lc => sub {
    my $query = $_;

    return unless $query =~ /^((what ((is|was|will) the )?)?(?<dort>date|time|day)( (was it|will it be|is it|be))? )?($operation_re|$from_re|$ago_re)[\?.]?$/i;

    my $action = $+{action};
    my $date   = $+{date};
    my $number = $+{number};
    my $unit   = $+{unit};
    my $dort   = $+{dort};

    return get_result_relative($date, $lang) unless defined $number;
    return get_result_action $action, $date, $number, $unit, $lang;
};

1;
