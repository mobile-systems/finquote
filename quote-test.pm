use Finance::Quote;






my %info = $quoter->fetch("moexbonds", $ticker); 
print "$ticker date: $info{$ticker,'date'} price: $info{$ticker,'price'}\n";