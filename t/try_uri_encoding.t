use lib '/home/falk/webgourmet/scripts';
use GourmetExport;
use Data::Dumper;
use Test::More qw( no_plan );

use JSON::XS qw(encode_json decode_json);
use File::Slurp qw(read_file write_file);

my $json = read_file('recipes.json', { binmode => ':raw' });
my $recipe_hash = decode_json($json);

sub by_title {
  $recipe_hash->{$a}->{'title'} cmp  $recipe_hash->{$b}->{'title'}
  ||
    $a <=> $b
}
foreach my $id (sort by_title keys %{ $recipe_hash }) {
  my $title = $id;
  if ($recipe_hash->{$id}->{'title'}) {
    $title = $recipe_hash->{$id}->{'title'};
  } else {
    print STDERR "Id $id: no title\n";
  };
  my $title_sanitized = $title;
  $title_sanitized =~ s{[^A-Za-z0-9 ]}{}g;
  my $file_name = "$title_sanitized$id.html";
  print STDERR "Title: $title\n";
  print STDERR "Title sanitized: $title_sanitized\n";
  # print STDERR "File name: $file_name\n";
}

