#!/usr/bin/perl -w


#    Copyright (C) 2017, Partizand https://github.com/partizand/finquote
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.

# Получает котировки предыдущего торгового дня на ММВБ
# Получает средневзвешенную цену предыдущего дня.

package Finance::Quote::Moex;

use 5.000000;
use strict;
use warnings;
#use encoding 'utf-8';

use vars qw($VERSION);


our $VERSION = '0.2';
# Облигации T+1 (ОФЗ)
our $BONDS_URL_T1 = "https://iss.moex.com/iss/engines/stock/markets/bonds/boardgroups/58/securities.csv";
# Облигации T0 (Всё остальное)
our $BONDS_URL_T0 = "https://iss.moex.com/iss/engines/stock/markets/bonds/boardgroups/7/securities.csv";
# Акции 
our $STOCK_URL = "https://iss.moex.com/iss/engines/stock/markets/shares/boardgroups/57/securities.csv";

use LWP::UserAgent;
use HTTP::Request::Common;

sub methods { return (moex_bond => \&moex_bond,
                      moex_bond_ofz => \&moex_bond_ofz,
					  moex_stock => \&moex_stock) }

{
  my @labels = qw/name price date isodate currency/;

  sub labels { return (moex_bond => \@labels,
                       moex_bond_ofz => \@labels,
					   moex_stock => \@labels) }
}
	
sub moex_bond_ofz
	{
	&moex($BONDS_URL_T1, "1", @_);
	}

sub moex_bond
	{
	&moex($BONDS_URL_T0, "1", @_);
	}
	
sub moex_stock
	{
	&moex($STOCK_URL, "", @_);
	}

sub moex {
	my $url = shift;
	my $is_bond = shift;
	my $quoter = shift;
	my @stocks = @_;
	
	my $sym;
	my $stock;
	my %info;
	my %stockhash;
	my @q;
	
	my $price;
	my $price_field;
	my $currency;
	
	foreach my $stock (@stocks) # Обнуляем признаки обработки тикеров
	  {
	   $stockhash{$stock} = 0;
	  }

	if ($is_bond)
		{
		$price_field = "PREVWAPRICE"; # Колонка с ценой для облигаций (средневзвешенная цена)
		}
	else
		{
		$price_field = "PREVLEGALCLOSEPRICE"; # Колонка с ценой для акций (цена закрытия)
		}
	
	
	my $ua = $quoter->user_agent; #http
	my $response = $ua->request(GET $url); #http begin
	
	unless ($response->is_success) 
		{
		foreach my $stock (@stocks) 
			{
			$info{$stock, "success"} = 0;
			$info{$stock, "errormsg"} = "HTTP failure";
			}
	
		return wantarray() ? %info : \%info;
		} #http end
		
	my $content = $response->content; #http
	
	my @lines = split(/\n/,$content); # split by lines
	
	shift @lines;
	shift @lines;
	
	my %fields = &getfields(shift @lines);
	
	foreach (@lines) 
		{
		if ($_ eq "") # После пустой строки все игнорируем
			{
			last;
			}
	
		@q = split(/;/,$_); # split by columns
		
		$sym = $q[$fields{'SECID'}]; #Код бумаги
		if ($sym) 
			{		      
			foreach my $stock (@stocks) 
				{
				if ( $sym eq $stock ) 
					{  
				
					#print (Msg "Found sym $stock close=$q[5] date=$q[1] \n");
					$info{$stock, "symbol"} = $stock; #Код
					$info{$stock, "name"} = $stock; 
					#$info{$stock, "shortname"} = $q[$fields{'SHORTNAME'}]; 
					
					$currency = $q[$fields{'CURRENCYID'}];
					if ($currency eq 'SUR')
						{
						$currency = "RUB";
						}
					$info{$stock, "currency"} = $currency;
					$info{$stock, "method"} = "moex";
					
					$price = $q[$fields{$price_field}];
					if ($price)
						{
						if ($is_bond)
							{$price = $price * 10;
							}
						$info{$stock, "price"} = $price;
						$stockhash{$stock} = 1;
						$info{$stock, "success"} = 1;
						}
				
					#$quoter->store_date(\%info, $stock,  {isodate => _my_time('isodate')});
					$quoter->store_date(\%info, $stock,  {isodate => $q[$fields{'PREVDATE'}]});
					
					#print ("Found sym $stock last=$info{$stock,'last'} date=$info{$stock,'date'} \n");  
					}
				}
			}

		}
	
	# check to make sure a value was returned for every fund requested
	foreach my $stock (keys %stockhash)
		{
		if ($stockhash{$stock} == 0)
			{
			$info{$stock, "success"}  = 0;
			$info{$stock, "errormsg"} = "Stock lookup failed";
			}
		}
		
	return wantarray() ? %info : \%info;
		
	
}
# возвращает ассоциативный массив - ключ - имя поля, значение - порядковый номр колонки
# По строке с названиями полей ИмяПоля;ИмяПоля1;ИмяПоля2
sub getfields
	{
	my ($head_line) = @_;
	
	my @fields_names = split(/;/,$head_line); # split by columns
	my $i=0;
	my %fields;
	foreach my $field_name (@fields_names)
		{
		$fields{$field_name} = $i;
		$i = $i + 1;
		}
	return wantarray() ? %fields : \%fields;
	}

1;
__END__
=head1 NAME

Finance::Quote::Moex - Obtain quotes from Moex 

=head1 SYNOPSIS

	use Finance::Quote;

	my $quoter = Finance::Quote->new("Moex");
	my %info = $quoter->fetch("moex_bond_ofz", "SU26218RMFS6"); # ОФЗ 26218
	print "$info{'SU26218RMFS6','date'} $info{'SU26218RMFS6','price'}\n";

=head1 DESCRIPTION

This module fetches bond share quotes information from the Moex http://www.moex.com. 
 
It's not loaded as default Finance::Quote module, so you need create it
 by Finance::Quote->new("Moex"). If you want it to load by default,
 make changes to Finance::Quote default module loader, or use 
 FQ_LOAD_QUOTELET environment variable. Gnucash example:
	FQ_LOAD_QUOTELET="-defaults Moex" gnucash

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::Moex :

name price date isodate currency
 
=head1 AUTHOR

,Partizand, https://github.com/partizand/finquote

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2017 by Partizand. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.0.8 or,
at your option, any later version of Perl 5 you may have available.

=cut
