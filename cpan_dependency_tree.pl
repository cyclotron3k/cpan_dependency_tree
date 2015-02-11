use 5.018;
 
use Data::Dumper;
use MetaCPAN::API;
use Storable;

my $root = 'Some::Package';
my %modules = ();
my %modules_errors = ();
my %distros = ();
my %distros_errors = ();
 
my $mcpan = MetaCPAN::API->new;
my $store = "$0.store";

if (-f $store)
{
	my $s = retrieve $store;
	%modules = %{$s->{'modules'}};
	%distros = %{$s->{'distros'}};
}

$modules{$root} = undef;

my $complete = 0;
until ($complete)
{
	$complete = 1;

	for my $name (grep {!defined $modules{$_}} keys %modules)
	{
		next if $modules_errors{$name} and $modules_errors{$name} >= 3;
		say "Getting module: $name";
		$complete  = 0;
		my $module = eval { $mcpan->module( $name ) };
		if ($@)
		{
			say "\e[31m$@\e[0m";
			$modules_errors{$name}++;
			next;
		};
		$modules{$name} = $module;
		$distros{$module->{distribution}} ||= undef;
	}

	for my $name (grep {!defined $distros{$_}} keys %distros)
	{
		next if $distros_errors{$name} and $distros_errors{$name} >= 3;
		say "Getting distro: $name";
		$complete = 0;
		my $dist  = eval { $mcpan->release( distribution => $name ) };
		if ($@)
		{
			say "\e[31m$@\e[0m";
			$distros_errors{$name}++;
			next;
		};
		$distros{$name} = $dist;
		foreach my $dep (@{ $dist->{dependency} })
		{
			$modules{$dep->{module}} ||= undef;
		}
	}

	store {modules => \%modules, distros => \%distros}, $store;

	print_dep_tree();

}


my %seen = ();

sub print_dep_tree
{
	%seen = ();
	say $root;
	_print_dep_tree($root, 1);
}

sub _print_dep_tree
{
	my ($node, $level) = @_;

	return unless defined $modules{$node};

	my @children = map {$_->{module}} @{$distros{$modules{$node}{distribution}}{dependency}};

	my @sn = grep {$seen{$_}}  @children;
	my @ns = grep {!$seen{$_}} @children;

	$seen{$_} = 1 for @ns;

	for my $m (@ns)
	{
		print "  " x $level;
		say $m;
		_print_dep_tree($m, $level + 1);
	}

	if (@sn)
	{
		print "  " x $level;
		say "and " . scalar(@sn) . " others";
	}
}
