import java.util.*;
import java.io.*;

// Non-public class named Main so the file name can be anything.
// Compile: javac -d {dir} {src}   Run: java -cp {dir} Main
class Main {
    static void solve(BufferedReader in, StringBuilder out) throws IOException {

    }

    public static void main(String[] args) throws IOException {
        BufferedReader in = new BufferedReader(new InputStreamReader(System.in));
        StringBuilder out = new StringBuilder();
        int tc = Integer.parseInt(in.readLine().trim());
        while (tc-- > 0) solve(in, out);
        System.out.print(out);
    }
}
