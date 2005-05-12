package Posy::Plugin::EditInfo;
use strict;

=head1 NAME

Posy::Plugin::EditInfo - Posy plugin to edit supplementary entry information.

=head1 VERSION

This describes version B<0.02> of Posy::Plugin::EditInfo.

=cut

our $VERSION = '0.02';

=head1 SYNOPSIS

    @plugins = qw(Posy::Core
	...
	Posy::Plugin::Info
	Posy::Plugin::EditInfo
	...);

    @actions = qw(init_params
	...
	process_edit_info_form
	...);

    @entry_actions = qw(init_params
	...
	set_edit_info_form
	...);

=head1 DESCRIPTION

This plugin enables the user to create and edit .info files of the
type used by L<Posy::Plugin::Info>.  This relies on external .htaccess
setup for password protection, so if you can't set such a thing up,
do not use this module unless you want anyone to be able to create
.info files.

This plugin provides $entry_edit_info_form flavour variable,
and 'set_edit_info_form' and 'process_edit_info_form' actions.

=head2 Password Protection

For details of how to set up password protection for a directory,
check your webserver documentation.  Here is some advice, however.

If you password-protect your whole site, then nobody could even view
the site without having a user-password.  This is probably not what you
want.  The easiest method of protecting editing is to make a copy
of your posy.cgi script (say, posy_edit.cgi) and make separate directory
to put it in (say, "cgi-bin/posy_edit_info/"), put the posy_edit.cgi
script into it, and password-protect that directory.

Then edit C<posy_edit.cgi> to add the Posy::Plugin::EditInfo configuration
requirements (and remove extra plugins that you don't actually need
for this).

=head2 Configuration

This expects configuration settings in the $self->{config} hash,
which, in the default Posy setup, can be defined in the main "config"
file in the config directory.

=over

=item B<edit_info_url>

The url of the edit-info CGI script.  (default: $self->{url})

=item B<edit_info_spec>

Define the info-fields and their properties.

    edit_info_spec:
      order:
        - Author
        - Title
	- Series
        - SeriesOrder
	- Rating
	- Summary
      default:
        type: text
	size: 40
      options:
        Summary:
          type: textarea
	  rows: 5
          cols: 70
        Rating:
          type: select
	  options:
	    - G
	    - PG
	    - PG13
	    - R
	    - NC17

The 'order' part of the spec is the order the fields are to be presented
in the form.
The 'options' part of the spec gives optional options for each field,
while the 'default' part of the spec gives the default kind of input-type
which fields are if they don't appear in the 'options' part.
The 'type' is the type of input field which will be used in the form.
The other parts are specific to the particular type of input field.

Possible types are:

=over

=item text

A normal "text" input field.  The 'size' gives the size of the field.

=item textarea

A "textarea" input field. The "rows" and "cols" are the rows and columns.

=item select

A "select" input field.  The "options" are the list of options for
that select.

=back

=back

=cut

our $edit_info_save_name = 'SaveInfo';
our $edit_info_entry_id_name = 'entry_info_entry_id';
our $edit_info_get_name = 'GetInfo';
our $edit_info_other_entry_id_name = 'entry_info_other_entry_id';

=head1 OBJECT METHODS

Documentation for developers and those wishing to write plugins.

=head2 init

Do some initialization; make sure that default config values are set.

=cut
sub init {
    my $self = shift;
    $self->SUPER::init();

    # set defaults
    $self->{config}->{edit_info_url} = $self->{url}
	if (!defined $self->{config}->{edit_info_url});
} # init

=head1 Flow Action Methods

Methods implementing actions.  All such methods expect a
reference to a flow-state hash, and generally will update
either that hash or the object itself, or both in the course
of their running.

=head2 process_edit_info_form

$self->process_edit_info_form($flow_state);

Processes the EntryInfo-related parameters and saves the data
to the correct .info file.

=cut
sub process_edit_info_form {
    my $self = shift;
    my $flow_state = shift;

    if (defined $self->{config}->{edit_info_spec}
	and $self->param($edit_info_save_name)
	and $self->param($edit_info_entry_id_name)
	)
    {
	$self->param($edit_info_entry_id_name) =~ m#([-\w/._]+)#;
	my $entry_id = $1;
	if (exists $self->{files}->{$entry_id}
	    and defined $self->{files}->{$entry_id})
	{
	    my $fh;
	    my $info_file = File::Spec->catfile($self->{data_dir}, "$entry_id.info");
	    if (!open($fh, ">", $info_file))
	    {
		warn "Could not open $info_file for writing: $!";
		return 0;
	    }
	    foreach my $field (@{$self->{config}->{edit_info_spec}->{order}})
	    {
		print $fh $field, ":", $self->param($field), "\n";
	    }
	    close($fh);
	}
    }
} # process_edit_info_form

=head1 Entry Action Methods

Methods implementing per-entry actions.

=head2 set_edit_info_form

$self->set_edit_info_form($flow_state, $current_entry, $entry_state);

Creates the EditInfo form and puts it into the $entry_edit_info_form
flavour variable.

=cut
sub set_edit_info_form {
    my $self = shift;
    my $flow_state = shift;
    my $current_entry = shift;
    my $entry_state = shift;

    if (defined $self->{config}->{edit_info_spec})
    {
	my $edit_url = $self->{config}->{edit_info_url};
	my $entry_id = $current_entry->{id};
	my $entry_path = $current_entry->{path};
	my $entry_basename = $current_entry->{basename};
	my $flavour = $self->{path}->{flavour};
	my %info = $self->info($entry_id);
	# check if we should set the info from another entry's info
	if ($self->param($edit_info_get_name)
	    and $self->param($edit_info_other_entry_id_name)
	   )
	{
	    $self->param($edit_info_other_entry_id_name) =~ m#([-\w/._]+)#;
	    my $other_entry_id = $1;
	    my %other_info = $self->info($other_entry_id);
	    while (my $key = each %other_info)
	    {
		if ($key ne 'Size'
		    and defined $other_info{$key}
		    and $other_info{$key})
		{
		    $info{$key} = $other_info{$key};
		}
	    }
	}

	my $form=<<EOT;
<form action="${edit_url}/${entry_path}/${entry_basename}.${flavour}">
<input type="hidden" name="$edit_info_entry_id_name" value="$entry_id"/>
<table border="1">
EOT
	foreach my $field (@{$self->{config}->{edit_info_spec}->{order}})
	{
	    $form .= "<tr><td><strong>$field</strong></td>\n";
	    my $use_default_type =
		(!exists $self->{config}->{edit_info_spec}->{options}->{$field});
	    my $field_type =
		($use_default_type
		 ? $self->{config}->{edit_info_spec}->{default}->{type}
		 : $self->{config}->{edit_info_spec}->{options}->{$field}->{type});
	    if ($field_type eq 'text')
	    {
		my $size =
		($use_default_type
		 ? $self->{config}->{edit_info_spec}->{default}->{size}
		 : $self->{config}->{edit_info_spec}->{options}->{$field}->{size});
		$form .=<<EOT;
<td><input type="text" name="$field" size="$size" value="$info{$field}"/>
EOT
	    }
	    elsif ($field_type eq 'textarea')
	    {
		my $rows =
		($use_default_type
		 ? $self->{config}->{edit_info_spec}->{default}->{rows}
		 : $self->{config}->{edit_info_spec}->{options}->{$field}->{rows});
		my $cols =
		($use_default_type
		 ? $self->{config}->{edit_info_spec}->{default}->{cols}
		 : $self->{config}->{edit_info_spec}->{options}->{$field}->{cols});
		$form .=<<EOT;
<td><textarea name="$field" rows="$rows" cols="$cols">
$info{$field}</textarea>
EOT
	    }
	    elsif ($field_type eq 'select')
	    {
		my @options =
		    @{$self->{config}->{edit_info_spec}->{options}->
		    {$field}->{options}};
		$form .=<<EOT;
<td><select name="$field">
EOT
		foreach my $opt (@options)
		{
		    if ($info{$field} eq $opt)
		    {
			$form .= "<option selected=\"1\">$opt</option>\n";
		    }
		    else
		    {
			$form .= "<option>$opt</option>\n";
		    }
		}
		$form .="</select>";
	    }
	    $form .= "</td></tr>\n";
	}
	$form.=<<EOT1;
</table>
<input type="Submit" name="$edit_info_save_name" value="Save Info"/>
<input type="Reset"/>
EOT1
	# list similar files in the same category
	my @similar_files = ();
	$entry_basename =~ m/^(\w\w)/;
	my $this_basename_start = $1;
	while (my ($id, $file_stuff) = each %{$self->{files}})
	{
	    if ($id ne $entry_id
		and $file_stuff->{cat_id} eq $self->{path}->{cat_id}
		and $file_stuff->{basename} =~ /^$this_basename_start/o)
	    {
		push @similar_files, $id;
	    }
	}
	my $get_info = '';
	if (@similar_files)
	{
	    $get_info=<<EOT;
<br/>
<input type="Submit" name="$edit_info_get_name" value="Get Info"/>
<select name="$edit_info_other_entry_id_name">
EOT
	    foreach my $id (sort @similar_files)
	    {
		my $id_basename = $self->{files}->{$id}->{basename};
		$get_info .= "<option value=\"$id\">$id_basename</option>\n";
	    }
	    $get_info.="</select>\n";
	}
	$form.="$get_info\n</form>";
	$current_entry->{edit_info_form} = $form;
    }
} # set_edit_info_form

=head1 INSTALLATION

Installation needs will vary depending on the particular setup a person
has.

=head2 Administrator, Automatic

If you are the administrator of the system, then the dead simple method of
installing the modules is to use the CPAN or CPANPLUS system.

    cpanp -i Posy::Plugin::EditInfo

This will install this plugin in the usual places where modules get
installed when one is using CPAN(PLUS).

=head2 Administrator, By Hand

If you are the administrator of the system, but don't wish to use the
CPAN(PLUS) method, then this is for you.  Take the *.tar.gz file
and untar it in a suitable directory.

To install this module, run the following commands:

    perl Build.PL
    ./Build
    ./Build test
    ./Build install

Or, if you're on a platform (like DOS or Windows) that doesn't like the
"./" notation, you can do this:

   perl Build.PL
   perl Build
   perl Build test
   perl Build install

=head2 User With Shell Access

If you are a user on a system, and don't have root/administrator access,
you need to install Posy somewhere other than the default place (since you
don't have access to it).  However, if you have shell access to the system,
then you can install it in your home directory.

Say your home directory is "/home/fred", and you want to install the
modules into a subdirectory called "perl".

Download the *.tar.gz file and untar it in a suitable directory.

    perl Build.PL --install_base /home/fred/perl
    ./Build
    ./Build test
    ./Build install

This will install the files underneath /home/fred/perl.

You will then need to make sure that you alter the PERL5LIB variable to
find the modules.

Therefore you will need to change the PERL5LIB variable to add
/home/fred/perl/lib

	PERL5LIB=/home/fred/perl/lib:${PERL5LIB}

=head1 REQUIRES

    Posy
    Posy::Core
    Posy::Plugin::Info

    Test::More

=head1 SEE ALSO

perl(1).
Posy

=head1 BUGS

Please report any bugs or feature requests to the author.

=head1 AUTHOR

    Kathryn Andersen (RUBYKAT)
    perlkat AT katspace dot com
    http://www.katspace.com

=head1 COPYRIGHT AND LICENCE

Copyright (c) 2005 by Kathryn Andersen

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1; # End of Posy::Plugin::EditInfo
__END__
