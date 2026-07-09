# BridgeWebs XML Editor

A Perl distribution for loading, editing, scoring, and saving BridgeWebs
USEBIO XML bridge session files.

## Modules

- **BridgeWebs::Session** — core session logic (load/save XML, scoring, match
  points, master point awards). No GUI dependency.
- **App::BridgeWebs::XMLEditor** — GTK3 graphical editor.
- **BridgeXMLEditor** — backward-compatible alias for the GTK3 editor.

## Installation

```bash
cpanm App::BridgeWebs::XMLEditor
```

Or from a checkout:

```bash
perl Makefile.PL
make
make test
sudo make install
```

For the graphical editor, install Gtk3 (often via your OS package manager) and
ensure a display is available.

## Usage

```bash
bridgewebs-xml-editor [session.xml]
```

Programmatically:

```perl
use BridgeWebs::Session;

my $session = BridgeWebs::Session->load_file('session.xml');
$session->recalculate_session_results();
$session->save_file();
```

## Requirements

- Perl 5.36+
- XML::Simple
- Gtk3 (for the graphical editor only)

## License

This software is licensed under the same terms as Perl 5.
