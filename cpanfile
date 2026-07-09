# Local development and CI
requires 'perl', '5.036';
requires 'XML::Simple', '2.18';

on 'test' => sub {
    requires 'Test::More', '0.98';
};

feature 'gui', 'GTK3 graphical editor' => sub {
    requires 'Gtk3';
};

feature 'author', 'Author tooling' => sub {
    requires 'Pod::Coverage', '0';
    requires 'Test::Pod', '1.00';
    requires 'Test::Pod::Coverage', '0';
};
