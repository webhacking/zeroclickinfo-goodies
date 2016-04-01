package DDG::Goodie::DateMath;
# ABSTRACT: add/subtract days/weeks/months/years to/from a date

use strict;
use DDG::Goodie;
with 'DDG::GoodieRole::Dates';
with 'DDG::GoodieRole::NumberStyler';
use DateTime::Duration;
use Lingua::EN::Numericalize;

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
    return '+' if $action =~ /^(\+|plus|add)$/i;
    return '-' if $action =~ /^(\-|minus|subtract)$/i;
}

my $clock_unit = qr/(?:second|minute|hour)s?/;

sub format_result {
    my ($out_date, $use_clock) = @_;
    my $output_date = format_date_for_display($out_date, $use_clock);
    return $output_date;
}

sub format_input {
    my ($input_date, $action, $unit, $input_number, $use_clock) = @_;
    my $in_date    = format_date_for_display($input_date, $use_clock);
    my $out_action = "$action $input_number $unit";
    return "$in_date $out_action";
}

my $number_re        = number_style_regex();

my $units = qr/(?<unit>second|minute|hour|day|week|month|year)s?/i;

my $relative_regex = qr/(?<number>$number_re|[a-z\s-]+)\s+$units/i;

my $action_re = qr/(?<action>plus|add|\+|\-|minus|subtract)/i;

my $operation_re = qr/$action_re\s$relative_regex/i;
my $time_24h = time_24h_regex();
my $time_12h = time_12h_regex();

sub build_result {
    my ($result, $formatted) = @_;
        return $result, structured_answer => {
            meta => {
                signal => 'high',
            },
            data => {
                title    => "$result",
                subtitle => "$formatted",
            },
            templates => {
                group => 'text',
            },
        };

}

sub get_result_relative {
    my ($date, $use_clock) = @_;
    my $parsed_date = parse_datestring_to_date($date);
    my $result = format_result $date, $use_clock or return;
    return build_result($result, ucfirst $date);
}

sub calculate_new_date {
    my ($compute_number, $unit, $input_date) = @_;
    my $dur = get_duration $compute_number, $unit;
    return $input_date->clone->add_duration($dur);
}

sub get_result_action {
    my ($action, $date, $number, $unit, $use_clock) = @_;
    $action = get_action_for $action or return;
    my $input_number = str2nbr($number);
    my $style = number_style_for($input_number) or return;
    my $compute_num = $style->for_computation($input_number);
    my $out_num     = $style->for_display($input_number);

    my $input_date = parse_datestring_to_date(
        defined($date) ? $date : "today") or return;

    my $compute_number = $action eq '-' ? 0 - $compute_num : $compute_num;
    my $out_date = calculate_new_date $compute_number, $unit, $input_date;
    $unit .= 's' if abs($compute_number) != 1;
    my $result = format_result($out_date, $use_clock);
    my $formatted_input = format_input($input_date, $action, $unit, $out_num, $use_clock);
    return build_result($result, $formatted_input);
}

handle query_lc => sub {
    my $query = $_;

    $query =~ s/([a-z]+) ($units)/@{[str2nbr($1)]} $2/g;
    my $specified_time = $query =~ /$time_24h|$time_12h/;
    my $has_time_words = $query =~ /time|$clock_unit/i;
    my $use_clock = $specified_time || $has_time_words;
    $query =~ s/[?.]$//;
    $query =~ s/^(what ((is|was|will) the )?)?(?<dort>date|time|day)( (was it|will it be|is it|be))?\s+//i;
    $query =~ s/\s*$operation_re\s*//;;
    my $action = $+{action};
    my $number = $+{number};
    my $unit   = $+{unit};
    return unless $query;
    unless ($action) {
        if (is_relative_datestring($query)) {
            return get_result_relative($query, $use_clock);
        }
        return;
    } else {
        return get_result_action($action, $query, $number, $unit, $use_clock);
    }
};

1;
