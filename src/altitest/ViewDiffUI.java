import javax.swing.*;
import javax.swing.table.DefaultTableModel;
import java.awt.*;
import java.awt.event.*;
import java.io.*;
import java.util.ArrayList;
import java.util.List;

public class ViewDiffUI {
    private final String pythonExe;
    private final String viewdiffScript;
    private final String runJson;
    private final String diffTool;

    private JFrame frame;
    private JTable table;
    private DefaultTableModel model;
    private JTextArea logArea;
    private JButton openButton;
    private JButton acceptButton;

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
        acceptButton = new JButton("Accept OUT -> LST");
        JButton refreshButton = new JButton("Refresh");

        openButton.addActionListener(e -> openSelected());
        acceptButton.addActionListener(e -> acceptSelected());
        refreshButton.addActionListener(e -> refreshList());

        buttonPanel.add(openButton);
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
        int row = table.getSelectedRow();
        if (row < 0) {
            openButton.setEnabled(false);
            acceptButton.setEnabled(false);
            return;
        }
        String status = String.valueOf(model.getValueAt(row, 1));
        openButton.setEnabled(true);
        acceptButton.setEnabled("FAIL".equals(status));
    }

    private void refreshList() {
        model.setRowCount(0);
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
