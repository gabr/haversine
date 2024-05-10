noremap <silent> <F9> :!rm data/*; time ./generate-data.zig data one 1 \| pv -t; ls -alh data/; cat data/*json; echo "data.f64:"; xxd -g 1 data/*-data.f64; echo "hsin.f64:"; xxd -g 1 data/*-hsin.f64; echo end<CR>
noremap <silent> <F10> :!rm data/*; time ./generate-data.zig data four 4 \| pv -t; ls -alh data/; cat data/*json; echo "data.f64:"; xxd -g 1 data/*-data.f64; echo "hsin.f64:"; xxd -g 1 data/*-hsin.f64; echo end<CR>
noremap <silent> <F11> :!rm data/*; time ./generate-data.zig data huge 1000000 \| pv -t; ls -alh data/<CR>
noremap <silent> <F12> :!rm data/*; zig build -O ReleaseFast; time ./generate-data data test 1000000 \| pv -t<CR>
