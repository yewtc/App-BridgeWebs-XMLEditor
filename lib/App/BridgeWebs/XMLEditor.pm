package App::BridgeWebs::XMLEditor;

use v5.36;
use Gtk3;
use BridgeWebs::Session;

our $VERSION = '0.001';

sub new ($class, $initial_file = undef) {
    my $self = {
        session => BridgeWebs::Session->new(),
        current_board => undef,
        selected_traveller_index => undef,
        widgets => {}
    };

    bless $self, $class;
    
    # Initialize Gtk3
    Gtk3::init();
    
    $self->create_interface();

    if (defined $initial_file && $initial_file ne '') {
        if (-f $initial_file) {
            eval {
                $self->load_xml_file($initial_file);
                $self->update_status("Loaded file: $initial_file");
            };
            if ($@) {
                $self->show_error('Error loading file', "Could not load $initial_file:\n$@");
            }
        } else {
            $self->show_error('File not found', "Could not open $initial_file");
        }
    }

    return $self;
}

sub create_interface ($self) {
    
    # Create main window
    $self->{widgets}->{window} = Gtk3::Window->new('toplevel');
    $self->{widgets}->{window}->set_title("Bridge XML Editor");
    $self->{widgets}->{window}->set_default_size(1200, 800);
    $self->{widgets}->{window}->signal_connect('delete-event' => sub { Gtk3::main_quit(); return 0; });
    
    # Create main container
    my $main_box = Gtk3::Box->new('vertical', 5);
    $self->{widgets}->{window}->add($main_box);
    
    # Create menu bar
    $self->create_menu();
    $main_box->pack_start($self->{widgets}->{menu_bar}, 0, 0, 0);
    
    # Create notebook for tabs
    $self->{widgets}->{notebook} = Gtk3::Notebook->new();
    $main_box->pack_start($self->{widgets}->{notebook}, 1, 1, 0);
    
    # Create tabs
    $self->create_overview_tab();
    $self->create_boards_tab();
    $self->create_players_tab();
    $self->create_results_tab();
    
    # Create status bar
    $self->{widgets}->{status_bar} = Gtk3::Statusbar->new();
    $main_box->pack_start($self->{widgets}->{status_bar}, 0, 0, 0);
    
    # Show all widgets
    $self->{widgets}->{window}->show_all();
}

sub create_menu ($self) {
    
    # Create menu bar
    my $menu_bar = Gtk3::MenuBar->new();
    
    # File menu
    my $file_menu = Gtk3::Menu->new();
    my $file_item = Gtk3::MenuItem->new_with_label("File");
    $file_item->set_submenu($file_menu);
    
    my $open_item = Gtk3::MenuItem->new_with_label("Open XML...");
    $open_item->signal_connect('activate' => sub { $self->open_file(); });
    $file_menu->append($open_item);
    
    my $save_item = Gtk3::MenuItem->new_with_label("Save");
    $save_item->signal_connect('activate' => sub { $self->save_file(); });
    $file_menu->append($save_item);
    
    my $save_as_item = Gtk3::MenuItem->new_with_label("Save As...");
    $save_as_item->signal_connect('activate' => sub { $self->save_as_file(); });
    $file_menu->append($save_as_item);
    
    $file_menu->append(Gtk3::SeparatorMenuItem->new());
    
    my $exit_item = Gtk3::MenuItem->new_with_label("Exit");
    $exit_item->signal_connect('activate' => sub { Gtk3::main_quit(); });
    $file_menu->append($exit_item);
    
    # View menu
    my $view_menu = Gtk3::Menu->new();
    my $view_item = Gtk3::MenuItem->new_with_label("View");
    $view_item->set_submenu($view_menu);
    
    my $refresh_item = Gtk3::MenuItem->new_with_label("Refresh");
    $refresh_item->signal_connect('activate' => sub { $self->refresh_views(); });
    $view_menu->append($refresh_item);

    my $recalc_results_item = Gtk3::MenuItem->new_with_label("Recalculate Results");
    $recalc_results_item->signal_connect('activate' => sub {
        $self->recalculate_session_results('Recalculated session results and master point awards');
    });
    $view_menu->append($recalc_results_item);
    
    # Add menus to menu bar
    $menu_bar->append($file_item);
    $menu_bar->append($view_item);
    
    # Store menu bar in widgets hash
    $self->{widgets}->{menu_bar} = $menu_bar;
}

sub create_overview_tab ($self) {
    
    my $overview_frame = Gtk3::Frame->new("Overview");
    $self->{widgets}->{notebook}->append_page($overview_frame, Gtk3::Label->new("Overview"));
    
    # Create scrolled window for text
    my $scrolled_window = Gtk3::ScrolledWindow->new();
    $overview_frame->add($scrolled_window);
    
    # Create text view
    $self->{widgets}->{overview_text} = Gtk3::TextView->new();
    $self->{widgets}->{overview_text}->set_wrap_mode('word-char');
    $scrolled_window->add($self->{widgets}->{overview_text});
}

sub create_boards_tab ($self) {
    
    my $boards_frame = Gtk3::Frame->new("Boards");
    $self->{widgets}->{notebook}->append_page($boards_frame, Gtk3::Label->new("Boards"));
    
    my $main_box = Gtk3::Box->new('vertical', 5);
    $boards_frame->add($main_box);
    
    # Board selection frame
    my $board_select_frame = Gtk3::Frame->new("Board Selection");
    $main_box->pack_start($board_select_frame, 0, 0, 5);
    
    my $board_select_box = Gtk3::Box->new('horizontal', 5);
    $board_select_frame->add($board_select_box);
    
    $board_select_box->pack_start(Gtk3::Label->new("Board:"), 0, 0, 5);
    
    # Board selector combobox
    $self->{widgets}->{board_selector} = Gtk3::ComboBoxText->new();
    $self->{widgets}->{board_selector}->signal_connect('changed' => sub { $self->on_board_selector_change(); });
    $board_select_box->pack_start($self->{widgets}->{board_selector}, 0, 0, 5);
    
    # Board details frame
    my $board_details_frame = Gtk3::Frame->new("Board Details");
    $main_box->pack_start($board_details_frame, 1, 1, 5);
    
    # Create tree view for board results
    my $scrolled_window = Gtk3::ScrolledWindow->new();
    $board_details_frame->add($scrolled_window);
    
    # Create list store (last two columns hold pair numbers for editing)
    my @columns = ("NS Pair", "EW Pair", "Contract", "By", "Tricks", "Score", "NS MP", "EW MP");
    my $list_store = Gtk3::ListStore->new(
        ('Glib::String') x (scalar(@columns) + 2)
    );
    
    $self->{widgets}->{board_tree} = Gtk3::TreeView->new_with_model($list_store);
    
    # Configure columns
    my %column_widths = (
        "NS Pair" => 280,
        "EW Pair" => 280,
        "Contract" => 80,
        "By" => 50,
        "Tricks" => 60,
        "Score" => 80,
        "NS MP" => 60,
        "EW MP" => 60
    );
    
    for my $i (0..$#columns) {
        my $renderer = Gtk3::CellRendererText->new();
        my $column = Gtk3::TreeViewColumn->new_with_attributes(
            $columns[$i], $renderer, "text" => $i
        );
        $column->set_sizing('fixed');
        $column->set_fixed_width($column_widths{$columns[$i]} || 100);
        $self->{widgets}->{board_tree}->append_column($column);
    }
    
    # Connect selection signal
    $self->{widgets}->{board_tree}->get_selection()->signal_connect('changed' => sub { $self->on_board_result_select(); });
    
    $scrolled_window->add($self->{widgets}->{board_tree});
    
    # Edit frame
    my $edit_frame = Gtk3::Frame->new("Edit Board Result");
    $main_box->pack_start($edit_frame, 0, 0, 5);
    
    my $edit_box = Gtk3::Box->new('vertical', 5);
    $edit_frame->add($edit_box);
    
    # Row 1
    my $row1 = Gtk3::Box->new('horizontal', 5);
    $edit_box->pack_start($row1, 0, 0, 5);
    
    $row1->pack_start(Gtk3::Label->new("NS Pair:"), 0, 0, 5);
    $self->{widgets}->{ns_pair_entry} = Gtk3::Entry->new();
    $row1->pack_start($self->{widgets}->{ns_pair_entry}, 0, 0, 5);
    
    $row1->pack_start(Gtk3::Label->new("EW Pair:"), 0, 0, 5);
    $self->{widgets}->{ew_pair_entry} = Gtk3::Entry->new();
    $row1->pack_start($self->{widgets}->{ew_pair_entry}, 0, 0, 5);
    
    # Row 2
    my $row2 = Gtk3::Box->new('horizontal', 5);
    $edit_box->pack_start($row2, 0, 0, 5);
    
    $row2->pack_start(Gtk3::Label->new("Contract:"), 0, 0, 5);
    $self->{widgets}->{contract_entry} = Gtk3::Entry->new();
    $row2->pack_start($self->{widgets}->{contract_entry}, 0, 0, 5);
    
    $row2->pack_start(Gtk3::Label->new("By:"), 0, 0, 5);
    $self->{widgets}->{by_entry} = Gtk3::Entry->new();
    $row2->pack_start($self->{widgets}->{by_entry}, 0, 0, 5);
    
    $row2->pack_start(Gtk3::Label->new("Tricks:"), 0, 0, 5);
    $self->{widgets}->{tricks_entry} = Gtk3::Entry->new();
    $row2->pack_start($self->{widgets}->{tricks_entry}, 0, 0, 5);
    
    # Row 3
    my $row3 = Gtk3::Box->new('horizontal', 5);
    $edit_box->pack_start($row3, 0, 0, 5);
    
    $row3->pack_start(Gtk3::Label->new("Score:"), 0, 0, 5);
    $self->{widgets}->{score_entry} = Gtk3::Entry->new();
    $row3->pack_start($self->{widgets}->{score_entry}, 0, 0, 5);
    
    $row3->pack_start(Gtk3::Label->new("NS MP:"), 0, 0, 5);
    $self->{widgets}->{ns_mp_entry} = Gtk3::Entry->new();
    $row3->pack_start($self->{widgets}->{ns_mp_entry}, 0, 0, 5);
    
    $row3->pack_start(Gtk3::Label->new("EW MP:"), 0, 0, 5);
    $self->{widgets}->{ew_mp_entry} = Gtk3::Entry->new();
    $row3->pack_start($self->{widgets}->{ew_mp_entry}, 0, 0, 5);
    
    # Button frame
    my $button_frame = Gtk3::Frame->new("Actions");
    $edit_box->pack_start($button_frame, 0, 0, 5);
    
    my $button_box = Gtk3::Box->new('horizontal', 5);
    $button_frame->add($button_box);
    
    my $add_button = Gtk3::Button->new_with_label("Add Result");
    $add_button->signal_connect('clicked' => sub { $self->add_board_result(); });
    $button_box->pack_start($add_button, 0, 0, 5);
    
    my $update_button = Gtk3::Button->new_with_label("Update Result");
    $update_button->signal_connect('clicked' => sub { $self->update_board_result(); });
    $button_box->pack_start($update_button, 0, 0, 5);
    
    my $delete_button = Gtk3::Button->new_with_label("Delete Result");
    $delete_button->signal_connect('clicked' => sub { $self->delete_board_result(); });
    $button_box->pack_start($delete_button, 0, 0, 5);
    
    my $calculate_button = Gtk3::Button->new_with_label("Calculate Score");
    $calculate_button->signal_connect('clicked' => sub { $self->calculate_score_from_contract(); });
    $button_box->pack_start($calculate_button, 0, 0, 5);
    
    my $recalculate_button = Gtk3::Button->new_with_label("Recalculate MP");
    $recalculate_button->signal_connect('clicked' => sub { $self->recalculate_all_match_points(); });
    $button_box->pack_start($recalculate_button, 0, 0, 5);
}

sub create_players_tab ($self) {
    
    my $players_frame = Gtk3::Frame->new("Players");
    $self->{widgets}->{notebook}->append_page($players_frame, Gtk3::Label->new("Players"));
    
    # Create scrolled window
    my $scrolled_window = Gtk3::ScrolledWindow->new();
    $players_frame->add($scrolled_window);
    
    # Create list store
    my $list_store = Gtk3::ListStore->new(
        'Glib::String',  # Pair Number
        'Glib::String',  # Player 1
        'Glib::String',  # Player 2
        'Glib::String',  # Place
        'Glib::String',  # Percentage
        'Glib::String',  # MP Awarded
        'Glib::String'   # MP Type
    );
    
    $self->{widgets}->{players_tree} = Gtk3::TreeView->new_with_model($list_store);
    
    # Configure columns
    my @columns = ("Pair Number", "Player 1", "Player 2", "Place", "Percentage", "MP Awarded", "MP Type");
    my %column_widths = (
        "Pair Number" => 100,
        "Player 1" => 200,
        "Player 2" => 200,
        "Place" => 80,
        "Percentage" => 100,
        "MP Awarded" => 100,
        "MP Type" => 100
    );
    
    for my $i (0..$#columns) {
        my $renderer = Gtk3::CellRendererText->new();
        my $column = Gtk3::TreeViewColumn->new_with_attributes(
            $columns[$i], $renderer, "text" => $i
        );
        $column->set_sizing('fixed');
        $column->set_fixed_width($column_widths{$columns[$i]} || 100);
        $self->{widgets}->{players_tree}->append_column($column);
    }
    
    $scrolled_window->add($self->{widgets}->{players_tree});
}

sub create_results_tab ($self) {
    
    my $results_frame = Gtk3::Frame->new("Results");
    $self->{widgets}->{notebook}->append_page($results_frame, Gtk3::Label->new("Results"));
    
    # Create scrolled window
    my $scrolled_window = Gtk3::ScrolledWindow->new();
    $results_frame->add($scrolled_window);
    
    # Create list store
    my $list_store = Gtk3::ListStore->new(
        'Glib::String',  # Place
        'Glib::String',  # Pair Number
        'Glib::String',  # Player 1
        'Glib::String',  # Player 2
        'Glib::String',  # Percentage
        'Glib::String',  # MP Awarded
        'Glib::String'   # MP Type
    );
    
    $self->{widgets}->{results_tree} = Gtk3::TreeView->new_with_model($list_store);
    
    # Configure columns
    my @columns = ("Place", "Pair Number", "Player 1", "Player 2", "Percentage", "MP Awarded", "MP Type");
    my %column_widths = (
        "Place" => 80,
        "Pair Number" => 100,
        "Player 1" => 200,
        "Player 2" => 200,
        "Percentage" => 100,
        "MP Awarded" => 100,
        "MP Type" => 100
    );
    
    for my $i (0..$#columns) {
        my $renderer = Gtk3::CellRendererText->new();
        my $column = Gtk3::TreeViewColumn->new_with_attributes(
            $columns[$i], $renderer, "text" => $i
        );
        $column->set_sizing('fixed');
        $column->set_fixed_width($column_widths{$columns[$i]} || 100);
        $self->{widgets}->{results_tree}->append_column($column);
    }
    
    $scrolled_window->add($self->{widgets}->{results_tree});
}

# Method stubs for menu actions
sub open_file ($self) {
    
    # Create file chooser dialog
    my $dialog = Gtk3::FileChooserDialog->new(
        "Open XML File",
        $self->{widgets}->{window},
        'open',
        'gtk-cancel' => 'cancel',
        'gtk-open' => 'accept'
    );
    
    # Set file filters
    my $filter = Gtk3::FileFilter->new();
    $filter->set_name("XML Files");
    $filter->add_pattern("*.xml");
    $dialog->add_filter($filter);
    
    # Show dialog and get response
    my $response = $dialog->run();
    
    if ($response eq 'accept') {
        my $filename = $dialog->get_filename();
        $dialog->destroy();
        
        # Load and parse the XML file
        eval {
            $self->load_xml_file($filename);
            $self->update_status("Loaded file: " . $filename);
        };
        if ($@) {
            $self->show_error("Error loading file", "Could not load file: $@");
        }
    } else {
        $dialog->destroy();
    }
}

# Supporting methods for open_file
sub load_xml_file ($self, $filename) {
    $self->{session} = BridgeWebs::Session->load_file($filename);
    $self->refresh_views();
}

sub update_status ($self, $message) {
    
    # Update the status bar
    $self->{widgets}->{status_bar}->push(0, $message);
}

sub show_error ($self, $title, $message) {
    
    # Create error dialog
    my $dialog = Gtk3::MessageDialog->new(
        $self->{widgets}->{window},
        'modal',
        'error',
        'ok',
        $message
    );
    $dialog->set_title($title);
    $dialog->run();
    $dialog->destroy();
}

sub show_warning ($self, $title, $message) {
    
    # Create warning dialog
    my $dialog = Gtk3::MessageDialog->new(
        $self->{widgets}->{window},
        'modal',
        'warning',
        'ok',
        $message
    );
    $dialog->set_title($title);
    $dialog->run();
    $dialog->destroy();
}

sub show_info ($self, $title, $message) {
    
    # Create info dialog
    my $dialog = Gtk3::MessageDialog->new(
        $self->{widgets}->{window},
        'modal',
        'info',
        'ok',
        $message
    );
    $dialog->set_title($title);
    $dialog->run();
    $dialog->destroy();
}

sub ask_yes_no ($self, $title, $message) {
    
    # Create yes/no dialog
    my $dialog = Gtk3::MessageDialog->new(
        $self->{widgets}->{window},
        'modal',
        'question',
        'yes-no',
        $message
    );
    $dialog->set_title($title);
    my $response = $dialog->run();
    $dialog->destroy();
    
    return ($response eq 'yes') ? 1 : 0;
}

sub get_xml_text ($self, $value) {
    return BridgeWebs::Session->get_xml_text($value);
}

sub get_pair_mp_awarded ($self, $pair) {
    return $self->{session}->get_pair_mp_awarded($pair);
}

sub get_pair_mp_type ($self, $pair) {
    return $self->{session}->get_pair_mp_type($pair);
}

sub set_pair_master_points ($self, $pair, $awarded, $type) {
    $self->{session}->set_pair_master_points($pair, $awarded, $type);
}

sub get_edit_fields ($self) {

    return {
        ns_pair => $self->{widgets}->{ns_pair_entry}->get_text(),
        ew_pair => $self->{widgets}->{ew_pair_entry}->get_text(),
        contract => $self->{widgets}->{contract_entry}->get_text(),
        played_by => $self->{widgets}->{by_entry}->get_text(),
        tricks => $self->{widgets}->{tricks_entry}->get_text(),
        score => $self->{widgets}->{score_entry}->get_text(),
        ns_mp => $self->{widgets}->{ns_mp_entry}->get_text(),
        ew_mp => $self->{widgets}->{ew_mp_entry}->get_text(),
    };
}

sub set_edit_fields ($self, $fields) {

    $self->{widgets}->{ns_pair_entry}->set_text($fields->{ns_pair} // '');
    $self->{widgets}->{ew_pair_entry}->set_text($fields->{ew_pair} // '');
    $self->{widgets}->{contract_entry}->set_text($fields->{contract} // '');
    $self->{widgets}->{by_entry}->set_text($fields->{played_by} // '');
    $self->{widgets}->{tricks_entry}->set_text($fields->{tricks} // '');
    $self->{widgets}->{score_entry}->set_text($fields->{score} // '');
    $self->{widgets}->{ns_mp_entry}->set_text($fields->{ns_mp} // '');
    $self->{widgets}->{ew_mp_entry}->set_text($fields->{ew_mp} // '');
}

sub clear_edit_fields ($self) {
    $self->set_edit_fields({});
}

sub build_traveller_line ($self, $fields) {
    return BridgeWebs::Session->build_traveller_line($fields);
}

sub get_pair_names_map ($self) {
    return $self->{session}->get_pair_names_map();
}

sub format_pair_label ($self, $pair_number, $names_map) {
    return BridgeWebs::Session->format_pair_label($pair_number, $names_map);
}

sub ensure_traveller_lines ($self, $board) {
    BridgeWebs::Session->ensure_traveller_lines($board);
}

sub apply_selected_result_edits ($self) {

    return unless defined $self->{selected_traveller_index};
    return unless $self->{current_board};

    my $fields = $self->get_edit_fields();
    return unless $fields->{ns_pair} && $fields->{ew_pair};

    $self->ensure_traveller_lines($self->{current_board});
    my $index = $self->{selected_traveller_index};
    return unless $index >= 0 && $index <= $#{$self->{current_board}->{TRAVELLER_LINE}};

    $self->{current_board}->{TRAVELLER_LINE}->[$index] = $self->build_traveller_line($fields);
    return 1;
}

sub recalculate_session_results ($self, $status = undef) {
    return unless $self->{session}->data;

    $self->apply_selected_result_edits();
    $self->{session}->recalculate_session_results();

    $self->update_players_view();
    $self->update_results_view();

    $self->update_status($status) if defined $status && $status ne '';
}

sub calculate_bridge_score ($self, $contract, $tricks, $declarer, $vulnerability = undef) {
    return BridgeWebs::Session->calculate_bridge_score(
        $contract, $tricks, $declarer, $vulnerability
    );
}

# View update methods
sub update_overview ($self) {
    my $data = $self->{session}->data;
    return unless $data;
    
    my $overview_text = "";
    
    # Add event information
    if ($data->{EVENT}) {
        my $event = $data->{EVENT};
        $overview_text .= "Event Type: " . ($event->{EVENT_TYPE} || "Unknown") . "\n";
        $overview_text .= "Date: " . ($event->{DATE} || "Unknown") . "\n";
        $overview_text .= "Pairs: " . ($event->{PAIRS} || "Unknown") . "\n";
        $overview_text .= "Boards Played: " . ($event->{BOARDS_PLAYED} || "Unknown") . "\n";
        $overview_text .= "Master Point Scale: " . ($event->{MASTER_POINT_SCALE} || "Unknown") . "\n\n";
    }
    
    # Add club information
    if ($data->{CLUB}) {
        my $club = $data->{CLUB};
        $overview_text .= "Club: " . ($club->{CLUB_NAME} || "Unknown") . "\n";
        $overview_text .= "Club ID: " . ($club->{CLUB_ID_NUMBER} || "Unknown") . "\n\n";
    }
    
    # Add board count
    if ($data->{EVENT} && $data->{EVENT}->{BOARD}) {
        $overview_text .= "Number of Boards: " . scalar(@{$data->{EVENT}->{BOARD}}) . "\n";
    }

    if ($data->{EVENT} && $data->{EVENT}->{PARTICIPANTS}) {
        my $participants = $data->{EVENT}->{PARTICIPANTS};
        if ($participants->{PAIR}) {
            $overview_text .= "Number of Pairs: " . scalar(@{$participants->{PAIR}}) . "\n";
        }
    }
    
    # Update the overview text view
    my $buffer = $self->{widgets}->{overview_text}->get_buffer();
    $buffer->set_text($overview_text);
}

sub update_players_view ($self) {
    my $data = $self->{session}->data;
    return unless $data && $data->{EVENT} && $data->{EVENT}->{PARTICIPANTS};

    my $participants = $data->{EVENT}->{PARTICIPANTS};
    return unless $participants->{PAIR};

    my $list_store = $self->{widgets}->{players_tree}->get_model();
    $list_store->clear();
    
    # Add pair data
    for my $pair (@{$participants->{PAIR}}) {
        my $iter = $list_store->append();
        $list_store->set($iter, 0, $pair->{PAIR_NUMBER} || "");
        
        # Get player names
        my $player1_name = "";
        my $player2_name = "";
        if ($pair->{PLAYER}) {
            if (scalar(@{$pair->{PLAYER}}) >= 1) {
                $player1_name = $pair->{PLAYER}->[0]->{PLAYER_NAME} || "";
            }
            if (scalar(@{$pair->{PLAYER}}) >= 2) {
                $player2_name = $pair->{PLAYER}->[1]->{PLAYER_NAME} || "";
            }
        }
        
        $list_store->set($iter, 1, $player1_name);
        $list_store->set($iter, 2, $player2_name);
        $list_store->set($iter, 3, $self->get_xml_text($pair->{PLACE}));
        $list_store->set($iter, 4, $self->get_xml_text($pair->{PERCENTAGE}));
        
        $list_store->set($iter, 5, $self->get_pair_mp_awarded($pair));
        $list_store->set($iter, 6, $self->get_pair_mp_type($pair));
    }
}

sub update_results_view ($self) {
    my $data = $self->{session}->data;
    return unless $data && $data->{EVENT} && $data->{EVENT}->{PARTICIPANTS};

    my $participants = $data->{EVENT}->{PARTICIPANTS};
    if (!$participants->{PAIR}) {
        return;
    }
    
    # Clear existing data
    my $list_store = $self->{widgets}->{results_tree}->get_model();
    $list_store->clear();
    
    # Sort pairs by place (handle ties like "3=")
    my @sorted_pairs = sort { 
        my $place_a = $a->{PLACE} || "999";
        my $place_b = $b->{PLACE} || "999";
        # Remove "=" from place for sorting
        $place_a =~ s/=//g;
        $place_b =~ s/=//g;
        $place_a <=> $place_b;
    } @{$participants->{PAIR}};
    
    # Add sorted pair data
    for my $pair (@sorted_pairs) {
        my $iter = $list_store->append();
        $list_store->set($iter, 0, $self->get_xml_text($pair->{PLACE}));
        $list_store->set($iter, 1, $self->get_xml_text($pair->{PAIR_NUMBER}));
        
        # Get player names
        my $player1_name = "";
        my $player2_name = "";
        if ($pair->{PLAYER}) {
            if (scalar(@{$pair->{PLAYER}}) >= 1) {
                $player1_name = $self->get_xml_text($pair->{PLAYER}->[0]->{PLAYER_NAME});
            }
            if (scalar(@{$pair->{PLAYER}}) >= 2) {
                $player2_name = $self->get_xml_text($pair->{PLAYER}->[1]->{PLAYER_NAME});
            }
        }
        
        $list_store->set($iter, 2, $player1_name);
        $list_store->set($iter, 3, $player2_name);
        $list_store->set($iter, 4, $self->get_xml_text($pair->{PERCENTAGE}));
        
        $list_store->set($iter, 5, $self->get_pair_mp_awarded($pair));
        $list_store->set($iter, 6, $self->get_pair_mp_type($pair));
    }
}

sub update_board_selector ($self) {
    my $data = $self->{session}->data;
    return unless $data && $data->{EVENT} && $data->{EVENT}->{BOARD};

    $self->{widgets}->{board_selector}->remove_all();

    for my $board (@{$data->{EVENT}->{BOARD}}) {
        my $board_number = $board->{BOARD_NUMBER} || "Unknown";
        $self->{widgets}->{board_selector}->append_text($board_number);
    }

    if (scalar(@{$data->{EVENT}->{BOARD}}) > 0) {
        $self->{widgets}->{board_selector}->set_active(0);
        $self->{current_board} = $data->{EVENT}->{BOARD}->[0];
        $self->update_board_view();
    }
}

sub update_board_view ($self) {
    return unless $self->{current_board};

    my $list_store = $self->{widgets}->{board_tree}->get_model();
    $list_store->clear();

    my %pair_names = $self->get_pair_names_map();
    
    # Add board result data
    if ($self->{current_board}->{TRAVELLER_LINE}) {
        for my $result (@{$self->{current_board}->{TRAVELLER_LINE}}) {
            my $ns_pair = $result->{NS_PAIR_NUMBER} || "";
            my $ew_pair = $result->{EW_PAIR_NUMBER} || "";
            my $iter = $list_store->append();
            $list_store->set($iter, 0, $self->format_pair_label($ns_pair, \%pair_names));
            $list_store->set($iter, 1, $self->format_pair_label($ew_pair, \%pair_names));
            $list_store->set($iter, 2, $result->{CONTRACT} || "");
            $list_store->set($iter, 3, $result->{PLAYED_BY} || "");
            $list_store->set($iter, 4, $result->{TRICKS} || "");
            $list_store->set($iter, 5, $result->{SCORE} || "");
            $list_store->set($iter, 6, $result->{NS_MATCH_POINTS} || "");
            $list_store->set($iter, 7, $result->{EW_MATCH_POINTS} || "");
            $list_store->set($iter, 8, $ns_pair);
            $list_store->set($iter, 9, $ew_pair);
        }
    }

    if (defined $self->{selected_traveller_index}) {
        my $path = Gtk3::TreePath->new_from_string($self->{selected_traveller_index});
        $self->{widgets}->{board_tree}->get_selection()->select_path($path);
    }
}

sub refresh_views ($self) {
    $self->update_overview();
    
    # Update players view
    $self->update_players_view();
    
    # Update results view
    $self->update_results_view();
    
    # Update board selector
    $self->update_board_selector();
    
    # Update board view if a board is selected
    if ($self->{current_board}) {
        $self->update_board_view();
    }
}

# Board result operations
sub add_board_result ($self) {

    unless ($self->{current_board}) {
        $self->show_warning('No board selected', 'Select a board before adding a result.');
        return;
    }

    my $fields = $self->get_edit_fields();
    unless ($fields->{ns_pair} && $fields->{ew_pair}) {
        $self->show_warning('Missing pairs', 'Enter both NS and EW pair numbers.');
        return;
    }

    $self->ensure_traveller_lines($self->{current_board});
    push @{$self->{current_board}->{TRAVELLER_LINE}}, $self->build_traveller_line($fields);

    $self->{selected_traveller_index} = $#{$self->{current_board}->{TRAVELLER_LINE}};
    $self->update_board_view();
    $self->recalculate_session_results();
    $self->update_status('Board result added');
}

sub update_board_result ($self) {

    unless (defined $self->{selected_traveller_index}) {
        $self->show_warning('No selection', 'Select a result to update.');
        return;
    }

    unless ($self->{current_board}) {
        $self->show_warning('No board selected', 'Select a board before updating a result.');
        return;
    }

    my $fields = $self->get_edit_fields();
    unless ($fields->{ns_pair} && $fields->{ew_pair}) {
        $self->show_warning('Missing pairs', 'Enter both NS and EW pair numbers.');
        return;
    }

    $self->ensure_traveller_lines($self->{current_board});
    my $index = $self->{selected_traveller_index};
    unless ($index >= 0 && $index <= $#{$self->{current_board}->{TRAVELLER_LINE}}) {
        $self->show_warning('Invalid selection', 'The selected result no longer exists.');
        return;
    }

    $self->{current_board}->{TRAVELLER_LINE}->[$index] = $self->build_traveller_line($fields);
    $self->update_board_view();
    $self->recalculate_session_results();
    $self->update_status('Board result updated');
}

sub delete_board_result ($self) {

    unless (defined $self->{selected_traveller_index}) {
        $self->show_warning('No selection', 'Select a result to delete.');
        return;
    }

    unless ($self->{current_board}) {
        $self->show_warning('No board selected', 'Select a board before deleting a result.');
        return;
    }

    unless ($self->ask_yes_no('Delete result', 'Are you sure you want to delete this result?')) {
        return;
    }

    $self->ensure_traveller_lines($self->{current_board});
    my $index = $self->{selected_traveller_index};
    splice @{$self->{current_board}->{TRAVELLER_LINE}}, $index, 1;

    $self->{selected_traveller_index} = undef;
    $self->clear_edit_fields();
    $self->update_board_view();
    $self->recalculate_session_results();
    $self->update_status('Board result deleted');
}

sub calculate_score_from_contract ($self) {

    my $fields = $self->get_edit_fields();
    unless ($fields->{contract} && defined $fields->{tricks} && $fields->{tricks} ne '' && $fields->{played_by}) {
        $self->show_warning('Missing data', 'Fill in contract, tricks, and declarer.');
        return;
    }

    my $calculated_score = $self->calculate_bridge_score(
        $fields->{contract},
        $fields->{tricks},
        $fields->{played_by}
    );

    $self->{widgets}->{score_entry}->set_text($calculated_score);
    $self->apply_selected_result_edits();

    my $line_count = 0;
    if ($self->{current_board} && $self->{current_board}->{TRAVELLER_LINE}) {
        $line_count = scalar @{$self->{current_board}->{TRAVELLER_LINE}};
    }

    if ($line_count >= 2) {
        $self->recalculate_all_match_points();
    } else {
        $self->recalculate_session_results();
        $self->update_status("Calculated score: $calculated_score");
    }
}

sub recalculate_all_match_points ($self) {
    unless ($self->{current_board}) {
        $self->show_warning('No board selected', 'Select a board first.');
        return;
    }

    $self->apply_selected_result_edits();
    my $updated_count = $self->{session}->recalculate_board_match_points($self->{current_board});

    if ($updated_count < 2) {
        $self->show_info('Not enough results', 'Need at least 2 scores to calculate match points.');
        return;
    }

    $self->update_board_view();
    $self->recalculate_session_results(
        "Recalculated match points for $updated_count results"
    );
}

# Event handlers
sub on_board_selector_change ($self) {

    my $active = $self->{widgets}->{board_selector}->get_active();
    my $data = $self->{session}->data;
    if ($active >= 0 && $data && $data->{EVENT} && $data->{EVENT}->{BOARD}) {
        $self->{current_board} = $data->{EVENT}->{BOARD}->[$active];
        $self->{selected_traveller_index} = undef;
        $self->clear_edit_fields();
        $self->update_board_view();
    }
}

sub on_board_result_select ($self) {

    my ($model, $iter) = $self->{widgets}->{board_tree}->get_selection()->get_selected();
    unless ($iter) {
        $self->{selected_traveller_index} = undef;
        return;
    }

    my $path = $model->get_path($iter);
    my ($index) = $path->get_indices();
    $self->{selected_traveller_index} = defined $index ? 0 + $index : undef;

    $self->set_edit_fields({
        ns_pair => $model->get($iter, 8) // '',
        ew_pair => $model->get($iter, 9) // '',
        contract => $model->get($iter, 2) // '',
        played_by => $model->get($iter, 3) // '',
        tricks => $model->get($iter, 4) // '',
        score => $model->get($iter, 5) // '',
        ns_mp => $model->get($iter, 6) // '',
        ew_mp => $model->get($iter, 7) // '',
    });
}

sub save_file ($self) {

    unless ($self->{session}->data) {
        $self->show_warning('Nothing to save', 'Open an XML file first.');
        return;
    }

    unless ($self->{session}->filename) {
        $self->save_as_file();
        return;
    }

    $self->save_xml_file($self->{session}->filename);
}

sub save_as_file ($self) {

    unless ($self->{session}->data) {
        $self->show_warning('Nothing to save', 'Open an XML file first.');
        return;
    }

    my $dialog = Gtk3::FileChooserDialog->new(
        'Save XML File',
        $self->{widgets}->{window},
        'save',
        'gtk-cancel' => 'cancel',
        'gtk-save' => 'accept'
    );

    my $filter = Gtk3::FileFilter->new();
    $filter->set_name('XML Files');
    $filter->add_pattern('*.xml');
    $dialog->add_filter($filter);

    my $response = $dialog->run();
    if ($response eq 'accept') {
        my $filename = $dialog->get_filename();
        $dialog->destroy();
        $filename .= '.xml' if $filename !~ /\.xml$/i;
        $self->save_xml_file($filename);
    } else {
        $dialog->destroy();
    }
}

sub save_xml_file ($self, $filename) {
    eval {
        my $basename = $self->{session}->save_file($filename);
        $self->update_status('Saved ' . $basename);
    };
    if ($@) {
        $self->show_error('Save failed', "Could not save file: $@");
    }
}

sub run ($self) {
    Gtk3::main();
}

1;

__END__

=head1 NAME

App::BridgeWebs::XMLEditor - GTK3 editor for BridgeWebs USEBIO XML files

=head1 SYNOPSIS

  use App::BridgeWebs::XMLEditor;

  my $app = App::BridgeWebs::XMLEditor->new('session.xml');
  $app->run();

=head1 DESCRIPTION

Graphical editor for BridgeWebs USEBIO XML bridge session files.

=head1 AUTHOR

BridgeWebs contributors

=cut
