package Post;

use feature ':5.30';
use strict;
use warnings;
 
sub new{
	my ($class,$args) = @_;
	
    my $self = bless {
		file => $args->{file},
		title => $args->{title},
		date => $args->{date},
        tags => $args->{tags},
        content => $args->{content}
    }, $class;
	
	return $self;
}

1;
