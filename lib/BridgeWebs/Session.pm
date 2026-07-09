package BridgeWebs::Session;

use v5.36;
use XML::Simple qw(XMLin XMLout);
use File::Basename qw(basename);

our $VERSION = '0.001';

my @FORCE_ARRAY = qw(PAIR PLAYER BOARD TRAVELLER_LINE);

sub new ($class, $data = undef, %opts) {
    return bless {
        data     => $data,
        filename => $opts{filename},
    }, $class;
}

sub load_file ($class, $filename) {
    my $data = XMLin(
        $filename,
        ForceArray   => \@FORCE_ARRAY,
        KeyAttr      => [],
        SuppressEmpty => 1,
        ContentKey   => 'content',
    );
    return $class->new($data, filename => $filename);
}

sub data ($self) {
    return $self->{data};
}

sub filename ($self) {
    return $self->{filename};
}

sub set_filename ($self, $filename) {
    $self->{filename} = $filename;
}

sub load ($self, $filename) {
    my $session = ref($self)->load_file($filename);
    $self->{data} = $session->{data};
    $self->{filename} = $filename;
    return $self;
}

sub save_file ($self, $filename = undef) {
    $filename //= $self->{filename}
        or die "No filename specified for save\n";

    my %data = %{$self->{data}};
    my $version = delete $data{Version} // '1.2';

    XMLout(
        \%data,
        OutputFile    => $filename,
        RootName      => 'USEBIO',
        NoAttr        => 1,
        KeyAttr       => [],
        SuppressEmpty => 1,
    );

    if (-e $filename) {
        my $content = do { local $/; open my $fh, '<', $filename or die $!; <$fh> };
        $content =~ s/<USEBIO>/<USEBIO Version="$version">/;
        open my $fh, '>', $filename or die $!;
        print {$fh} qq{<?xml version="1.0" encoding="utf-8"?>\n$content};
        close $fh;
    }

    $self->{data}->{Version} = $version;
    $self->{filename} = $filename;
    return basename($filename);
}

sub get_xml_text ($class, $value) {
    return '' unless defined $value;
    if (ref($value) eq 'HASH') {
        return defined $value->{content} ? "$value->{content}" : '';
    }
    return "$value";
}

sub get_pair_mp_awarded ($self, $pair) {
    return '' unless $pair && $pair->{MASTER_POINTS};
    return $self->get_xml_text($pair->{MASTER_POINTS}->{MASTER_POINTS_AWARDED});
}

sub get_pair_mp_type ($self, $pair) {
    return '' unless $pair && $pair->{MASTER_POINTS};
    return $self->get_xml_text($pair->{MASTER_POINTS}->{MASTER_POINT_TYPE});
}

sub set_pair_master_points ($self, $pair, $awarded, $type) {
    my $mp = $self->ensure_master_points($pair);
    $mp->{MASTER_POINTS_AWARDED} = defined $awarded && $awarded ne '' ? "$awarded" : '';
    $mp->{MASTER_POINT_TYPE}     = defined $type   && $type   ne '' ? "$type"   : '';
}

sub build_traveller_line ($class, $fields) {
    return {
        NS_PAIR_NUMBER  => $fields->{ns_pair}   // '',
        EW_PAIR_NUMBER  => $fields->{ew_pair}   // '',
        CONTRACT        => $fields->{contract}  // '',
        PLAYED_BY       => $fields->{played_by} // '',
        TRICKS          => $fields->{tricks}    // '',
        SCORE           => $fields->{score}     // '',
        NS_MATCH_POINTS => $fields->{ns_mp}     // '',
        EW_MATCH_POINTS => $fields->{ew_mp}     // '',
    };
}

sub get_pair_names_map ($self) {
    my %map;
    my $event = $self->{data}->{EVENT} or return %map;
    my $participants = $event->{PARTICIPANTS} or return %map;
    my $pairs = $participants->{PAIR} or return %map;

    for my $pair (@$pairs) {
        my $pair_number = $pair->{PAIR_NUMBER} // '';
        next unless $pair_number ne '';

        my @names;
        if ($pair->{PLAYER}) {
            for my $player (@{$pair->{PLAYER}}) {
                push @names, $player->{PLAYER_NAME} if $player->{PLAYER_NAME};
            }
        }

        $map{$pair_number} = @names ? join(' & ', @names) : '';
    }

    return %map;
}

sub format_pair_label ($class, $pair_number, $names_map) {
    $pair_number //= '';
    return '' unless $pair_number ne '';

    my $names = $names_map->{$pair_number};
    return $names ? "$pair_number - $names" : "Pair $pair_number";
}

sub ensure_traveller_lines ($class, $board) {
    return unless $board;
    $board->{TRAVELLER_LINE} ||= [];
    $board->{TRAVELLER_LINE} = [ $board->{TRAVELLER_LINE} ]
        unless ref($board->{TRAVELLER_LINE}) eq 'ARRAY';
}

sub get_max_mp_per_board ($self) {
    my $max_lines = 0;
    my $boards = $self->{data}->{EVENT}->{BOARD} if $self->{data} && $self->{data}->{EVENT};
    return 0 unless $boards;

    for my $board (@$boards) {
        next unless $board->{TRAVELLER_LINE};
        my $lines = scalar @{$board->{TRAVELLER_LINE}};
        $max_lines = $lines if $lines > $max_lines;
    }

    return $max_lines > 1 ? 2 * ($max_lines - 1) : 0;
}

sub ceil_div ($numerator, $denominator) {
    return 0 unless $denominator;
    return int( ( $numerator + $denominator - 1 ) / $denominator );
}

sub round_mp_up ($self, $value) {
    return 0 if $value <= 0;
    my $whole = int($value);
    return ( $value == $whole ) ? $whole : $whole + 1;
}

sub get_event_board_band ($self) {
    my $event  = $self->{data}->{EVENT};
    my $boards = $event->{BOARDS_PLAYED};
    if ( !defined $boards || $boards eq '' ) {
        $boards = scalar @{ $event->{BOARD} || [] };
    }
    $boards = int($boards) || 0;

    return '12-17' if $boards <= 17;
    return '18-35' if $boards <= 35;
    return '36+';
}

sub get_num_mp_award_places ($self) {
    my $event        = $self->{data}->{EVENT};
    my $participants = $event->{PARTICIPANTS};
    my $pairs        = int( $event->{PAIRS} || 0 );
    if ( !$pairs && $participants && $participants->{PAIR} ) {
        $pairs = scalar @{ $participants->{PAIR} };
    }

    my $band = $self->get_event_board_band();
    return ceil_div( $pairs, 4 ) if $band eq '12-17';
    return ceil_div( $pairs, 3 ) if $band eq '18-35';
    return ceil_div( $pairs, 2 );
}

sub get_mp_unit_award ($self) {
    my $event        = $self->{data}->{EVENT};
    my $scale        = $event->{MASTER_POINT_SCALE} // 'Club';
    my $two_winner   = int( $event->{WINNER_TYPE} // 1 ) == 2;

    my $unit = $two_winner ? 10 : 6;
    my %scale_multiplier = (
        Club     => 1,
        District => 1.5,
        County   => 2,
        Regional => 3,
        National => 4,
    );

    $unit *= ( $scale_multiplier{$scale} // 1 );
    return $unit;
}

sub get_master_point_type ($self) {
    my $scale = $self->{data}->{EVENT}->{MASTER_POINT_SCALE} // 'Club';
    return 'black'  if $scale eq 'Club';
    return 'silver' if $scale eq 'District';
    return 'green'  if $scale eq 'County';
    return 'gold'   if $scale eq 'Regional';
    return 'gold'   if $scale eq 'National';
    return 'black';
}

sub build_mp_award_schedule ($self, $num_awards) {
    return [] unless $num_awards;

    my $unit = $self->get_mp_unit_award();
    my $top  = $unit * $num_awards;

    return [ map { $top - $unit * ( $_ - 1 ) } 1 .. $num_awards ];
}

sub mp_award_for_rank_range ($self, $start_rank, $end_rank, $schedule) {
    return '' unless @$schedule && $start_rank >= 1;

    my $sum = 0;
    for my $rank ( $start_rank .. $end_rank ) {
        next if $rank > @$schedule;
        $sum += $schedule->[ $rank - 1 ];
    }

    my $count = $end_rank - $start_rank + 1;
    return '' unless $count;

    my $share = $sum / $count;
    my $minimum = $self->get_mp_unit_award();
    $share = $minimum if $share > 0 && $share < $minimum;

    return $self->round_mp_up($share);
}

sub ensure_master_points ($self, $pair) {
    $pair->{MASTER_POINTS} ||= {};
    return $pair->{MASTER_POINTS};
}

sub clear_master_point_awards ($self, $participants) {
    for my $pair ( @{ $participants->{PAIR} || [] } ) {
        $self->set_pair_master_points( $pair, '', '' );
    }
}

sub master_points_enabled ($self) {
    my $flag = $self->get_xml_text( $self->{data}->{EVENT}->{MPS_AWARDED_FLAG} );
    return 0 if $flag =~ /^N/i || $flag =~ /^no$/i || $flag eq '0';
    return 1;
}

sub recalculate_session_results ($self) {
    return 0 unless $self->{data} && $self->{data}->{EVENT};

    my $max_mp_per_board = $self->get_max_mp_per_board();
    return 0 unless $max_mp_per_board;

    my %stats;
    for my $board ( @{ $self->{data}->{EVENT}->{BOARD} || [] } ) {
        next unless $board->{TRAVELLER_LINE};
        for my $line ( @{ $board->{TRAVELLER_LINE} } ) {
            my $ns_pair = $line->{NS_PAIR_NUMBER} // '';
            my $ew_pair = $line->{EW_PAIR_NUMBER} // '';
            if ( $ns_pair ne '' ) {
                $stats{$ns_pair}{mp} += ( $line->{NS_MATCH_POINTS} || 0 );
                $stats{$ns_pair}{boards}++;
            }
            if ( $ew_pair ne '' ) {
                $stats{$ew_pair}{mp} += ( $line->{EW_MATCH_POINTS} || 0 );
                $stats{$ew_pair}{boards}++;
            }
        }
    }

    my $participants = $self->{data}->{EVENT}->{PARTICIPANTS};
    return 0 unless $participants && $participants->{PAIR};

    my @ranked;
    for my $pair ( @{ $participants->{PAIR} } ) {
        my $pair_number   = $pair->{PAIR_NUMBER} // '';
        my $boards_played = $stats{$pair_number}{boards} || 0;
        my $total_mp      = $stats{$pair_number}{mp}      || 0;
        my $percentage    = $boards_played
            ? 100 * $total_mp / ( $boards_played * $max_mp_per_board )
            : 0;

        push @ranked, {
            pair       => $pair,
            percentage => $percentage,
        };
    }

    @ranked = sort { $b->{percentage} <=> $a->{percentage} } @ranked;

    my $award_places        = $self->get_num_mp_award_places();
    my $award_schedule      = $self->build_mp_award_schedule($award_places);
    my $master_point_type   = $self->get_master_point_type();
    my $award_master_points = $self->master_points_enabled();

    if ($award_master_points) {
        $self->clear_master_point_awards($participants);
    }

    my $index = 0;
    while ( $index < @ranked ) {
        my $end = $index;
        while (
            $end + 1 < @ranked
            && abs( $ranked[ $end + 1 ]{percentage} - $ranked[$index]{percentage} ) < 0.005
        ) {
            $end++;
        }

        my $place     = $index + 1;
        my $end_rank  = $end + 1;
        my $place_str = ( $end > $index ) ? "${place}=" : "$place";
        my $mp_awarded = '';

        if ( $award_master_points && $place <= $award_places ) {
            my $share_end = $end_rank < $award_places ? $end_rank : $award_places;
            $mp_awarded = $self->mp_award_for_rank_range( $place, $share_end, $award_schedule );
        }

        for my $i ( $index .. $end ) {
            $ranked[$i]->{pair}->{PERCENTAGE} = sprintf( '%.2f', $ranked[$i]->{percentage} );
            $ranked[$i]->{pair}->{PLACE}      = $place_str;

            if ($award_master_points) {
                if ( $mp_awarded ne '' ) {
                    $self->set_pair_master_points(
                        $ranked[$i]->{pair}, $mp_awarded, $master_point_type
                    );
                }
                else {
                    $self->set_pair_master_points( $ranked[$i]->{pair}, '', '' );
                }
            }
        }
        $index = $end + 1;
    }

    return scalar @ranked;
}

sub recalculate_board_match_points ($self, $board) {
    $self->ensure_traveller_lines($board);
    my @lines = @{ $board->{TRAVELLER_LINE} || [] };
    return 0 if @lines < 2;

    my @scores = map { int( $_->{SCORE} || 0 ) } @lines;
    @scores = sort { $b <=> $a } @scores;

    my $total_pairs   = @scores;
    my $updated_count = 0;

    for my $line (@lines) {
        my $line_score = int( $line->{SCORE} || 0 );
        my $position   = 0;

        for ( my $i = 0 ; $i < @scores ; $i++ ) {
            if ( $scores[$i] == $line_score ) {
                $position = $i;
                last;
            }
        }

        my ( $ns_mp, $ew_mp );
        if ( $position == 0 ) {
            $ns_mp = $total_pairs - 1;
            $ew_mp = 0;
        }
        elsif ( $position == $total_pairs - 1 ) {
            $ns_mp = 0;
            $ew_mp = $total_pairs - 1;
        }
        else {
            $ns_mp = $total_pairs - 1 - $position;
            $ew_mp = $position;
        }

        $line->{NS_MATCH_POINTS} = $ns_mp;
        $line->{EW_MATCH_POINTS} = $ew_mp;
        $updated_count++;
    }

    return $updated_count;
}

sub calculate_bridge_score ($class, $contract, $tricks, $declarer, $vulnerability = undef) {
    $vulnerability ||= 'None';

    return 0 if !$contract || uc($contract) eq 'PASS';

    $contract = uc($contract);

    my ( $level, $suit, $doubled, $redoubled ) = ( 0, '', 0, 0 );

    if ( $contract =~ /XX/ ) {
        $redoubled = 1;
        $contract =~ s/XX//;
    }
    elsif ( $contract =~ /X/ ) {
        $doubled = 1;
        $contract =~ s/X//;
    }

    if ( $contract =~ /^(\d)(.+)$/ ) {
        $level = $1;
        $suit  = $2;
    }

    return 0 if $level == 0;

    my $tricks_needed = 6 + $level;
    my $tricks_taken  = int($tricks) || 0;
    my $score         = 0;

    if ( $tricks_taken >= $tricks_needed ) {
        my $base_score = 0;
        if ( $suit =~ /^NT|N$/ ) {
            $base_score = 40 + ( $level - 1 ) * 30;
        }
        elsif ( $suit =~ /^[SH]$/ ) {
            $base_score = $level * 30;
        }
        else {
            $base_score = $level * 20;
        }

        $base_score *= 2 if $doubled;
        $base_score *= 4 if $redoubled;

        my $game_bonus = 0;
        if ( $base_score >= 100 ) {
            if ( $declarer =~ /^[NS]$/ ) {
                $game_bonus = ( $vulnerability =~ /^(NS|Both)$/ ) ? 500 : 300;
            }
            else {
                $game_bonus = ( $vulnerability =~ /^(EW|Both)$/ ) ? 500 : 300;
            }
        }

        my $slam_bonus = 0;
        if ( $level >= 7 ) {
            if ( $declarer =~ /^[NS]$/ ) {
                $slam_bonus = ( $vulnerability =~ /^(NS|Both)$/ ) ? 2000 : 1500;
            }
            else {
                $slam_bonus = ( $vulnerability =~ /^(EW|Both)$/ ) ? 2000 : 1500;
            }
        }
        elsif ( $level >= 6 ) {
            if ( $declarer =~ /^[NS]$/ ) {
                $slam_bonus = ( $vulnerability =~ /^(NS|Both)$/ ) ? 750 : 500;
            }
            else {
                $slam_bonus = ( $vulnerability =~ /^(EW|Both)$/ ) ? 750 : 500;
            }
        }

        if ( $declarer =~ /^[NS]$/ ) {
            $score = $base_score + $game_bonus + $slam_bonus;
        }
        else {
            $score = -( $base_score + $game_bonus + $slam_bonus );
        }
    }
    else {
        my $undertricks = $tricks_needed - $tricks_taken;
        my $penalty     = 0;

        if ($doubled) {
            if ($redoubled) {
                if (   ( $declarer =~ /^[NS]$/ && $vulnerability =~ /^(NS|Both)$/ )
                    || ( $declarer =~ /^[EW]$/ && $vulnerability =~ /^(EW|Both)$/ ) )
                {
                    $penalty = $undertricks * 600;
                }
                else {
                    $penalty = $undertricks * 400;
                }
            }
            elsif (   ( $declarer =~ /^[NS]$/ && $vulnerability =~ /^(NS|Both)$/ )
                || ( $declarer =~ /^[EW]$/ && $vulnerability =~ /^(EW|Both)$/ ) )
            {
                $penalty = $undertricks * 300;
            }
            else {
                $penalty = $undertricks * 200;
            }
        }
        elsif (   ( $declarer =~ /^[NS]$/ && $vulnerability =~ /^(NS|Both)$/ )
            || ( $declarer =~ /^[EW]$/ && $vulnerability =~ /^(EW|Both)$/ ) )
        {
            $penalty = $undertricks * 200;
        }
        else {
            $penalty = $undertricks * 100;
        }

        $score = ( $declarer =~ /^[NS]$/ ) ? -$penalty : $penalty;
    }

    return $score;
}

1;

__END__

=head1 NAME

BridgeWebs::Session - BridgeWebs USEBIO XML session data and scoring logic

=head1 SYNOPSIS

  use BridgeWebs::Session;

  my $session = BridgeWebs::Session->load_file('session.xml');
  $session->recalculate_board_match_points($session->data->{EVENT}{BOARD}[0]);
  $session->recalculate_session_results();
  $session->save_file();

=head1 DESCRIPTION

Loads, manipulates, and saves BridgeWebs USEBIO XML bridge session files.
Provides scoring, match-point, and master-point calculation without a GUI.

=head1 AUTHOR

BridgeWebs contributors

=cut
