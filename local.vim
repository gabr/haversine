noremap <silent> <F9> :SH rm data/*; time ./generate-data.zig data three 3 \| pv -t; ls -alh data/; cat data/*json; echo "data.f64:"; xxd -g 1 data/*-data.f64; echo "hsin.f64:"; xxd -g 1 data/*-hsin.f64; echo end<CR>

noremap <silent> <F10> :SH time ./parse-data.zig data three \| pv -t; cat data/three-info.txt \| grep Haver<CR>
noremap <silent> <F11> :SH time ./parse-data.zig data three -valid \| pv -t; cat data/three-info.txt \| grep Haver<CR>

noremap <silent> <F12> :SH ./parse-data.zig<CR>
