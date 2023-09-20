/*
** Convert a binary to a CMD file
**
** by Oscar Toledo G.
** https://nanochess.org/
**
** Creation date: Aug/31/2023.
*/

#include <stdio.h>

char buffer[260];

/*
** Main program
*/
int main(int argc, char *argv[])
{
        FILE *input;
        FILE *output;
        char *ap;
        int c;
        int d;
        int offset;
        int exec;

        if (argc != 5) {
                fprintf(stderr, "Usage: cmd source.bin target.cmd hex_start hex_exec\n");
                exit(1);
        }
        c = 1;
        input = fopen(argv[c], "rb");
        if (input == NULL) {
                fprintf(stderr, "Couldn't open input file '%s'.\n", argv[c]);
                exit(1);
        }
        c++;
        output = fopen(argv[c], "wb");
        if (output == NULL) {
                fprintf(stderr, "Couldn't open input file '%s'.\n", argv[c]);
                exit(1);
        }
        buffer[0] = 0x05;
        buffer[1] = 0x06;
        ap = argv[c];
        d = 2;
        while (*ap && *ap != '.' && d < 8) {
                buffer[d] = toupper(*ap);
                ap++;
                d++;
        }
        while (d < 8) {
                buffer[d] = ' ';
                d++;
        }
        fwrite(buffer, 1, 8, output);

        c++;
        offset = strtol(argv[c], NULL, 16);

        c++;
        exec = strtol(argv[c], NULL, 16);

        while (d = fread(buffer + 4, 1, 256, input)) {
                buffer[0] = 0x01;
                buffer[1] = (d + 2) & 0xff;
                buffer[2] = offset & 0xff;
                buffer[3] = offset >> 8;
                fwrite(buffer, 1, d + 4, output);
                offset += d;
        }
        buffer[0] = 0x02;
        buffer[1] = 0x02;
        buffer[2] = exec & 0xff;
        buffer[3] = exec >> 8;
        fwrite(buffer, 1, 4, output);
        fclose(output);
        fclose(input);
        exit(0);
}

