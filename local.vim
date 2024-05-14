noremap <silent> <F9> :!rm data/*; time ./generate-data.zig data three 3 \| pv -t; ls -alh data/; cat data/*json; echo "data.f64:"; xxd -g 1 data/*-data.f64; echo "hsin.f64:"; xxd -g 1 data/*-hsin.f64; echo end<CR>

noremap <silent> <F10> :!time ./parse-data.zig data three \| pv -t<CR>
