use strict;
use warnings FATAL => qw(all);
use POSIX;
use Imager;
use Getopt::Long;
use File::Basename;
use Pod::Usage;

sub data_iterate{
    my $filename = shift;
    my $func = shift;
    open my $fh, "<", $filename or die $!;
    binmode $fh;

    my $data = "";
    while(my $bytes_read = read($fh, $data, 3)){
        my @byte_array = split "",$data;
        $func->(\@byte_array);
    }
    close $fh;
}

sub data_encode{
    my $filename = shift;
    my $filesize = -s $filename;
    my $imgsize_w = ceil(sqrt($filesize / 3)) + ceil(length($filename) /3);
    my $imgsize_h = ceil(sqrt($filesize / 3)) + 1;

    my $im = Imager->new(xsize => $imgsize_w, ysize => $imgsize_h, channels => 4);
    my $color_bg = Imager::Color->new(0,0,0,0);

    my $pixel_x = 0;
    my $pixel_y = 0;
    my $color_encoder = sub {
        my $bytes = shift;
        my $color = $color_bg;
        if(scalar @$bytes == 1){
            $color = Imager::Color->new(ord $$bytes[0], 0, 0, 64)
        }elsif(scalar @$bytes == 2){
            $color = Imager::Color->new(ord $$bytes[0], ord $$bytes[1], 0, 128)
        }elsif(scalar @$bytes == 3){
            $color = Imager::Color->new(ord $$bytes[0], ord $$bytes[1], ord $$bytes[2], 255)
        }
        return $color;
    };
    data_iterate($filename, sub{
            my $bytes = shift;
            if($pixel_x >= $imgsize_w){
                $pixel_y++;
                $pixel_x = 0;
            }
            $im->setpixel(x=>$pixel_x, y=>$pixel_y, color=>$color_encoder->($bytes));
            $pixel_x += 1;
        });
    my $aref = [];
    $pixel_x = 0;
    $pixel_y = $im->getheight()-1;
    for my $c(split "",$filename){
        push @$aref, $c;
        if(scalar(@$aref) >= 3){
            my $color = $color_encoder->($aref);
            $aref = [];
            $im->setpixel(x=>$pixel_x, y=>$pixel_y, color=>$color);
            $pixel_x++;
            if($pixel_x > $imgsize_w){
                $pixel_x = 0;
                $pixel_y++;
            }
        }
    }
    if(scalar @$aref > 0){
        my $color = $color_encoder->($aref);
        $im->setpixel(x=>$pixel_x, y=>$pixel_y, color=>$color);
    }
    my $output_filename = fileparse($filename);
    $output_filename =~ s/\..+$//;
    $im->write(file => $output_filename . ".png" ) or die $im->errstr;
}

sub data_decode{
    my $filename = shift;
    my $im = Imager->new();
    $im->read(file=>$filename) or die "Cannot read $filename: ", $im->errstr;
    my $height = $im->getheight();
    my $fname_x = 0;
    my $original_filname_string = "";
    {   #fetch the orignal filename encoded at the end of the image
        while(1){
            my $color = $im->getpixel(x=>$fname_x, y=>$height-1);
            my ($r, $g, $b, $a) = $color->rgba();
            if($a == 0){
                last;
            }else{
                if($a == 64){
                    $original_filname_string .= chr($r);
                }elsif($a == 128){
                    $original_filname_string .= chr($r) . chr($g);
                }else{
                    $original_filname_string .= chr($r) . chr($g) . chr($b);
                }
                $fname_x++;
            }
        }
    }
    {
        #decode the rest of the image to an output file
        my $pixel_x = 0;
        my $pixel_y = 0;
        my $width = $im->getwidth();
        my $height = $im->getheight();
        open my $out_fh, ">:raw", "decoded_" . $original_filname_string or die "couldn't open file: " . $!;
        while(1){
            my $color = $im->getpixel(x=>$pixel_x, y=>$pixel_y);
            my ($r, $g, $b, $a) = $color->rgba();
            if($a == 0){
                last;
            }else{
                if($a == 64){
                    print $out_fh chr($r);
                }elsif($a == 128){
                    print $out_fh chr($r) . chr($g);
                }else{
                    print $out_fh chr($r) . chr($g) . chr($b);
                }
                $pixel_x++;
                if($pixel_x >= $width){
                    $pixel_x = 0;
                    $pixel_y++;
                }
            }
        }
        close $out_fh;
    }
}

sub main{
   my $filename= '';
   my $encode_f = 0;
   my $decode_f = 0;
   my $help_f = 0;
   GetOptions(
       "filename=s" => \$filename,
       "encode" => sub { $encode_f = 1 },
       "decode" => sub { $decode_f = 1 },
       "help" => sub { $help_f = 1 }
   );
   if($encode_f and $filename){
       data_encode($filename);
   }elsif($decode_f and $filename){
       data_decode($filename);
   }elsif($help_f){
       pod2usage(-exitval => 0, -verbose => 2);    
   }else{
       pod2usage(1);
   }
}
main();
#my $filename = $ARGV[0];
#data_encode($filename);
#data_decode("testout.png");

__END__

=head1 data2img

data2img - Convert regular data to png images

=head1 SYNPOSIS

data2img [-e|-d] -f filename

=head1 OPTIONS

=over 8

=item B<-help>

Show man page

=item B<-e>

Encode given file specified by -f

=item B<-d>

Decode given file specified by -f

=item B<-f>

Specify the file which to encode/decode

=back

=head1 DESCRIPTION

B<data2img> will encode raw data into a .png file which can then be
decoded and the original data retrieved.

=cut
