import javax.swing.*;
import javax.swing.table.DefaultTableModel;
import java.awt.*;
import java.awt.event.*;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class ViewDiffUI {
    private static class RowInfo {
        final int index;
        final String status;
        final String reason;
        final String sql;
        final String lst;
        final String out;
        final String err;

        RowInfo(int index, String status, String reason, String sql, String lst, String out, String err) {
            this.index = index;
            this.status = status;
            this.reason = reason;
            this.sql = sql;
            this.lst = lst;
            this.out = out;
            this.err = err;
        }
    }

    private final String pythonExe;
    private final String viewdiffScript;
    private final String runJson;
    private final String diffTool;

    private JFrame frame;
    private JTable table;
    private DefaultTableModel model;
    private JTextArea logArea;
    private JButton openButton;
    private JButton viewOutButton;
    private JButton acceptButton;
    private final Map<Integer, RowInfo> rowsByIndex = new HashMap<>();

    public ViewDiffUI(String pythonExe, String viewdiffScript, String runJson, String diffTool) {
        this.pythonExe = pythonExe;
        this.viewdiffScript = viewdiffScript;
        this.runJson = runJson;
        this.diffTool = diffTool;
    }

    public static void main(String[] args) {
        if (args.length < 3) {
            System.err.println("Usage: java ViewDiffUI.java <pythonExe> <viewdiffScript> <runJson> [diffTool]");
            System.exit(1);
        }
        String diffTool = args.length >= 4 ? args[3] : "";
        SwingUtilities.invokeLater(() -> {
            ViewDiffUI ui = new ViewDiffUI(args[0], args[1], args[2], diffTool);
            ui.buildAndShow();
        });
    }

    private void buildAndShow() {
        frame = new JFrame("viewdiff");
        frame.setDefaultCloseOperation(JFrame.DISPOSE_ON_CLOSE);
        frame.setSize(1200, 700);
        frame.setLayout(new BorderLayout());

        model = new DefaultTableModel(new Object[]{"Index", "Status", "Reason", "SQL"}, 0) {
            @Override
            public boolean isCellEditable(int row, int column) {
                return false;
            }
        };

        table = new JTable(model);
        table.setSelectionMode(ListSelectionModel.SINGLE_SELECTION);
        table.getSelectionModel().addListSelectionListener(e -> updateButtons());
        table.addMouseListener(new MouseAdapter() {
            @Override
            public void mouseClicked(MouseEvent e) {
                if (e.getClickCount() == 2 && table.getSelectedRow() >= 0) {
                    openSelected();
                }
            }
        });

        JScrollPane tableScroll = new JScrollPane(table);
        frame.add(tableScroll, BorderLayout.CENTER);

        JPanel buttonPanel = new JPanel(new FlowLayout(FlowLayout.LEFT));
        openButton = new JButton("Open Diff");
        viewOutButton = new JButton("View OUT");
        acceptButton = new JButton("Accept OUT -> LST");
        JButton refreshButton = new JButton("Refresh");

        openButton.addActionListener(e -> openSelected());
        viewOutButton.addActionListener(e -> viewOutSelected());
        acceptButton.addActionListener(e -> acceptSelected());
        refreshButton.addActionListener(e -> refreshList());

        buttonPanel.add(openButton);
        buttonPanel.add(viewOutButton);
        buttonPanel.add(acceptButton);
        buttonPanel.add(refreshButton);

        logArea = new JTextArea(8, 80);
        logArea.setEditable(false);
        JScrollPane logScroll = new JScrollPane(logArea);

        JPanel southPanel = new JPanel(new BorderLayout());
        southPanel.add(buttonPanel, BorderLayout.NORTH);
        southPanel.add(logScroll, BorderLayout.CENTER);

        frame.add(southPanel, BorderLayout.SOUTH);

        refreshList();
        frame.setVisible(true);
    }

    private void updateButtons() {
        RowInfo info = selectedRowInfo();
        if (info == null) {
            openButton.setEnabled(false);
            viewOutButton.setEnabled(false);
            acceptButton.setEnabled(false);
            return;
        }
        openButton.setEnabled(true);
        viewOutButton.setEnabled(info.out != null && !info.out.isEmpty());
        acceptButton.setEnabled("FAIL".equals(info.status));
    }

    private void refreshList() {
        model.setRowCount(0);
        rowsByIndex.clear();
        List<String> lines = runCommand(buildBaseCommand("--list-lines"));
        for (String line : lines) {
            if (line.trim().isEmpty()) {
                continue;
            }
            String[] parts = line.split("\t", -1);
            if (parts.length < 4) {
                continue;
            }
            model.addRow(new Object[]{parts[0], parts[1], parts[2], parts[3]});
            try {
                int idx = Integer.parseInt(parts[0].trim());
                String lst = parts.length >= 5 ? parts[4] : "";
                String out = parts.length >= 6 ? parts[5] : "";
                String err = parts.length >= 7 ? parts[6] : "";
                rowsByIndex.put(idx, new RowInfo(idx, parts[1], parts[2], parts[3], lst, out, err));
            } catch (NumberFormatException ignored) {
                // keep table row; row map is optional for malformed index lines
            }
        }
        appendLog("list refreshed: " + model.getRowCount() + " rows");
        updateButtons();
    }

    private void openSelected() {
        Integer idx = selectedIndex();
        if (idx == null) {
            return;
        }
        List<String> out = runCommand(buildBaseCommand("--open-index", String.valueOf(idx)));
        appendLog(joinLines(out));
    }

    private void viewOutSelected() {
        RowInfo info = selectedRowInfo();
        if (info == null) {
            return;
        }
        if (info.out == null || info.out.isEmpty()) {
            appendLog("selected row has no out path");
            return;
        }
        openOutWindow(info);
    }

    private void acceptSelected() {
        int row = table.getSelectedRow();
        if (row < 0) {
            return;
        }
        String status = String.valueOf(model.getValueAt(row, 1));
        if (!"FAIL".equals(status)) {
            appendLog("accept is only enabled for FAIL rows");
            return;
        }
        Integer idx = selectedIndex();
        if (idx == null) {
            return;
        }

        int confirm = JOptionPane.showConfirmDialog(
                frame,
                "Selected FAIL case를 OUT -> LST로 덮어쓸까요?",
                "Confirm Accept",
                JOptionPane.YES_NO_OPTION
        );
        if (confirm != JOptionPane.YES_OPTION) {
            return;
        }

        List<String> out = runCommand(buildBaseCommand("--accept-index", String.valueOf(idx), "--yes"));
        appendLog(joinLines(out));
        refreshList();
    }

    private Integer selectedIndex() {
        int row = table.getSelectedRow();
        if (row < 0) {
            return null;
        }
        try {
            return Integer.parseInt(String.valueOf(model.getValueAt(row, 0)).trim());
        } catch (Exception e) {
            appendLog("invalid index in table");
            return null;
        }
    }

    private RowInfo selectedRowInfo() {
        Integer idx = selectedIndex();
        if (idx == null) {
            return null;
        }
        return rowsByIndex.get(idx);
    }

    private void openOutWindow(RowInfo info) {
        JFrame outFrame = new JFrame("OUT [" + info.index + "] " + info.sql);
        outFrame.setDefaultCloseOperation(JFrame.DISPOSE_ON_CLOSE);
        outFrame.setSize(1200, 800);
        outFrame.setLocationRelativeTo(frame);
        outFrame.setResizable(true);
        outFrame.setLayout(new BorderLayout());

        JLabel pathLabel = new JLabel("OUT: " + info.out);
        pathLabel.setBorder(BorderFactory.createEmptyBorder(8, 8, 8, 8));
        outFrame.add(pathLabel, BorderLayout.NORTH);

        JTextArea outArea = new JTextArea();
        outArea.setEditable(false);
        outArea.setFont(new Font(Font.MONOSPACED, Font.PLAIN, 12));
        outArea.setText(readOutFile(info.out));
        outArea.setCaretPosition(0);

        JScrollPane scroll = new JScrollPane(outArea);
        outFrame.add(scroll, BorderLayout.CENTER);

        JPanel controls = new JPanel(new FlowLayout(FlowLayout.LEFT));
        JButton reloadButton = new JButton("Reload");
        JButton acceptInWindowButton = new JButton("Accept OUT -> LST");
        JButton closeButton = new JButton("Close");

        reloadButton.addActionListener(e -> {
            outArea.setText(readOutFile(info.out));
            outArea.setCaretPosition(0);
        });
        acceptInWindowButton.setEnabled("FAIL".equals(info.status));
        acceptInWindowButton.addActionListener(e -> {
            int confirm = JOptionPane.showConfirmDialog(
                    outFrame,
                    "Selected FAIL case를 OUT -> LST로 덮어쓸까요?",
                    "Confirm Accept",
                    JOptionPane.YES_NO_OPTION
            );
            if (confirm != JOptionPane.YES_OPTION) {
                return;
            }
            List<String> out = runCommand(buildBaseCommand("--accept-index", String.valueOf(info.index), "--yes"));
            appendLog(joinLines(out));
            refreshList();
        });
        closeButton.addActionListener(e -> outFrame.dispose());

        controls.add(reloadButton);
        controls.add(acceptInWindowButton);
        controls.add(closeButton);
        outFrame.add(controls, BorderLayout.SOUTH);

        outFrame.setVisible(true);
    }

    private String readOutFile(String outPath) {
        if (outPath == null || outPath.isEmpty()) {
            return "out path is empty";
        }
        File f = new File(outPath);
        if (!f.exists()) {
            return "out file not found: " + outPath;
        }
        try {
            byte[] bytes = Files.readAllBytes(f.toPath());
            return new String(bytes, StandardCharsets.UTF_8);
        } catch (Exception e) {
            return "failed to read out file: " + e.getMessage();
        }
    }

    private List<String> buildBaseCommand(String... tail) {
        List<String> cmd = new ArrayList<>();
        cmd.add(pythonExe);
        cmd.add(viewdiffScript);
        cmd.add("--run-json");
        cmd.add(runJson);
        if (diffTool != null && !diffTool.isEmpty()) {
            cmd.add("--diff-tool");
            cmd.add(diffTool);
        }
        for (String t : tail) {
            cmd.add(t);
        }
        return cmd;
    }

    private List<String> runCommand(List<String> cmd) {
        List<String> lines = new ArrayList<>();
        ProcessBuilder pb = new ProcessBuilder(cmd);
        pb.redirectErrorStream(true);
        try {
            Process p = pb.start();
            try (BufferedReader r = new BufferedReader(new InputStreamReader(p.getInputStream()))) {
                String line;
                while ((line = r.readLine()) != null) {
                    lines.add(line);
                }
            }
            p.waitFor();
        } catch (Exception e) {
            lines.add("command failed: " + e.getMessage());
        }
        return lines;
    }

    private String joinLines(List<String> lines) {
        if (lines.isEmpty()) {
            return "(no output)";
        }
        StringBuilder sb = new StringBuilder();
        for (String line : lines) {
            sb.append(line).append('\n');
        }
        return sb.toString();
    }

    private void appendLog(String text) {
        logArea.append(text);
        if (!text.endsWith("\n")) {
            logArea.append("\n");
        }
        logArea.setCaretPosition(logArea.getDocument().getLength());
    }
}
