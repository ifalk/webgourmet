#!/usr/bin/perl
package Local::Modulino::DB2JSON;

__PACKAGE__->run( @ARGV ) unless caller();

use warnings;
use strict;
use English;

use Data::Types qw(:all);

use Data::Dumper;
use Carp;
use Carp::Assert;

use Pod::Usage;
use Getopt::Long;

use utf8;

=head1 NAME

perl db2json.pl 

=head1 USAGE

   perl db2json.pl recipes.db

=head1 DESCRIPTION

Reads gourmet recipe db (sqlite) and produces a json data structure, written to STDOUT

=head1 REQUIRED ARGUMENTS

The recipe db

=head1 OPTIONS

=cut

binmode(STDERR, 'encoding(UTF-8)');
#binmode(STDOUT, 'encoding(UTF-8)');

use DBI;
use DBD::SQLite::Constants qw/:file_open/;

use JSON;

use strict;

sub run
{

  unless (@ARGV) { pod2usage(2) }; 

  my $database = $ARGV[0];

  my $class = shift;

  my $dbh = $class->get_db_handle($database);

  my $some_recipe_ids = [ qw(246 1122 1302) ];

  my $sth = $class-> fetch_some_ingredients($dbh, $some_recipe_ids);

  my $recipes_ing = $class->handle_ingredients($sth);

  print STDERR Dumper($recipes_ing);
}

sub get_last_access
{
  my $class = shift;
  my $database = shift;


  my $last_access = 'undef';
  
  my $dbh = $class->get_db_handle($database);
  my $stmt = qq(select date(last_access, 'unixepoch') from info;);
  my $sth = $dbh->prepare($stmt);

  my $rv = $sth->execute() or die $DBI::errstr;
  if($rv < 0) {
    print $DBI::errstr;
  }

  $last_access = ($sth->fetchrow_array())[0];

  return $last_access;

}

sub get_db_handle
{


  my $class = shift;
  my $database = shift;

  my $driver = "SQLite";
  my $dsn = "DBI:$driver:dbname=$database";
  my $userid = "";
  my $password = "";
  my $dbh = DBI->connect($dsn, $userid, $password, { 
    RaiseError => 1,
    sqlite_open_flags => SQLITE_OPEN_READONLY,
    sqlite_unicode => 1, 
			 })
    or die $DBI::errstr;

  print STDERR "Opened database successfully\n";

  return $dbh;
}

sub fetch_some_ingredients
{
  my $class = shift;
  my $dbh = shift;
  my $recipe_ids = shift;

# get ingredients and build id -> ingredient hash

  my $recipe_id_string = join(', ', @{ $recipe_ids });
  my $ing_stmt = qq(select * from ingredients where recipe_id in ($recipe_id_string);); 
  my $ing_sth = $dbh->prepare( $ing_stmt);
  my $rv = $ing_sth->execute() or die $DBI::errstr;
  if($rv < 0) {
    print $DBI::errstr;
  }

  return $ing_sth;
}

sub fetch_ingredients
{
  my $class = shift;
  my $dbh = shift;

# get ingredients and build id -> ingredient hash

  my $ing_stmt = qq(select * from ingredients); 
  my $ing_sth = $dbh->prepare( $ing_stmt);
  my $rv = $ing_sth->execute() or die $DBI::errstr;
  if($rv < 0) {
    print $DBI::errstr;
  }

  return $ing_sth;
}

sub fetch_amounts
{

  # fetch distinct amounts in ingredient table (for testing)

  my $class = shift;
  my $dbh = shift;


  my $stmt = qq(select distinct amount from ingredients); 
  my $sth = $dbh->prepare( $stmt);
  my $rv = $sth->execute() or die $DBI::errstr;
  if($rv < 0) {
    print $DBI::errstr;
  }

  return $sth;

}

sub fetch_images
{
  # fetch images (for testing)

  my $class = shift;
  my $dbh = shift;

  my $stmt = qq(select id, image, thumb from recipe where deleted=0);
  my $sth = $dbh->prepare($stmt);

  my $rv = $sth->execute() or die $DBI::errstr;
  if($rv < 0) {
    print $DBI::errstr;
  }

  return $sth;
}

sub handle_ingredients
{
  my $class = shift;
  my $ing_sth = shift;
  my $recipes_ing = {};

  while (my $ing_list = $ing_sth->fetchrow_hashref()) {
    next if ($ing_list->{deleted});

    my $recipe_id = $ing_list->{recipe_id};

    my $item = $ing_list->{item};

    my $ing_group = $class->handle_inggroup($ing_list->{inggroup});
    
    my $unit = $class->handle_unit($ing_list->{unit});

    my $amount = $class->handle_amount($ing_list->{amount});

    my $optional = $class->handle_optional($ing_list->{optional});

    my %fields = (
      'unit' => $unit,
	'amount' => $amount,
	'optional' => $optional
    );
    while ( my ($key, $value) = each(%fields) ) {
      $recipes_ing->{$recipe_id}->{$ing_group}->{$item}->{$key} = $value;
    };

    if ($unit and ($unit eq 'recipe')) {
      $recipes_ing->{$recipe_id}->{$ing_group}->{$item}->{refid} = $ing_list->{refid};
    }
  }


  return $recipes_ing;
};

sub handle_inggroup
{
  my $class = shift;
  my $inggroup = shift;

  if ($inggroup) {
    return $inggroup;
  } else {
    return 'none';
  }

};

sub handle_unit
{
  my $class = shift;
  my $unit = shift;

  return $unit;
}

sub handle_amount
{
  my $class = shift;
  my $amount = shift;

  return $amount;
}

sub handle_optional
{
  my $class = shift;
  my $optional = shift;

  if ($optional) {
    $optional = 1;
  } else {
    $optional = 0;
  }

  return $optional;
}

sub float_to_frac {
  my $class = shift;
  my $n = shift;
  my $approx = shift;

  unless ($approx) {
    $approx = 0.01;
  }

  my %keep_divisors = (
    2 => 1,
    3 => 1,
    4 => 1,
    5 => 1,
    6 => 1,
    8 => 1,
    10 => 1,
    16 => 1
  );
  
  unless ($n) {
    return '';
  }

  if (is_whole($n)) {
    return $n;
  }
  
  my $i = int($n);
  my $rem = $n - $i;

  if ($rem and $rem<$approx) {
    return "$i";
  }
  
  my ($h, $k) = $class->fractify($rem, $approx);
  if ($keep_divisors{$k}) {
    if ($i) {
      return "$i $h/$k";
    }
    return "$h/$k";
  }

  my $rounded = sprintf("%.2f", $n);
  return $rounded;

}

sub fractify {
  my $class = shift;
  my $n = shift;
  my $approx = shift;

  if ($n eq '') { die "number required\n"; }

  unless ($approx) {
    $approx = 0.01;
  }

  
  use Math::BigInt;
  use Math::BigRat;

  my $x = my $y = Math::BigRat->new($n)->babs();
  my $h = my $k1 = Math::BigInt->new(1);
  my $k = my $h1 = Math::BigInt->new(0);

  while (1) {
    my $t = $y->as_int();
    ($h, $h1) = ($t * $h + $h1, $h);
    ($k, $k1) = ($t * $k + $k1, $k);
    my $val = Math::BigRat->new($h, $k);
    my $err = $val - $x;
    # my $out = sprintf "%s: %s / %s = %.16g (%.1g)\n", $t, $h, $k, $val, $err;
    # print STDERR $out, "\n";
    last if (abs($err) < $approx);
    $y -= $t or last;
    $y = 1 / $y;
  }

  return ($h, $k);
}


__END__
