import java.sql.*;

public class DbCheck {
    public static void main(String[] args) throws Exception {
        String url = "jdbc:postgresql://localhost:5432/violation_db";
        String user = "postgres";
        String pass = "2457";
        
        try (Connection conn = DriverManager.getConnection(url, user, pass)) {
            System.out.println("Connected to Host Postgres.");
            try (Statement stmt = conn.createStatement()) {
                ResultSet rs = stmt.executeQuery("SELECT id, station_name, registration_code FROM complaint_app.police_station ORDER BY id");
                while (rs.next()) {
                    System.out.printf("ID: %d | Name: %s | Code: %s%n", rs.getLong("id"), rs.getString("station_name"), rs.getString("registration_code"));
                }
            }
        }
    }
}
