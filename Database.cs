using Microsoft.Data.SqlClient;
using System.Data;
namespace DataBase
{
    class DataBase
    {
        private SqlConnection connection;
        private String connectionString = "Data Source=(LocalDB)\\MSSQLLocalDB;AttachDbFilename=C:\\Users\\User\\source\\repos\\DataBase\\DataBase\\Flow.mdf;Integrated Security=True";
        public DataBase()
        {
            connection = new SqlConnection(connectionString);
        }

        public bool request_user(string Email, string Password)
        {
            String querry = $"SELECT * FROM Utilizatori WHERE Email='{Email}' AND Parola='{Password}'";
            SqlCommand cmd = new SqlCommand(querry, this.connection);
            var reader = cmd.ExecuteReader();
            if (reader.Read()) {
                return true;
            }
            return false;
            
        }

        public void post_user(string Email, string Password, string username)
        {
            String querry = $"INSERT INTO Utilizatori (Email,Parola,Username,isAdmin) VALUES ('{Email}','{Password}','{username}','{0}')";
            SqlCommand cmd = new SqlCommand(querry,this.connection);
            cmd.ExecuteNonQuery();
        }

        public void post_point(String Latitudine,String Longitudine,String tip,String User)
        {
            String querry = $"INSERT INTO Puncte (Latitudine,Longitudine,Tip,[User]) VALUES ('{Latitudine}','{Longitudine}','{tip}','{User}')";
            SqlCommand cmd = new SqlCommand(querry, this.connection);
            cmd.ExecuteNonQuery();
        }

        public List<String[]> request_point(String Latitudine, String Longitudine, String tip, String User)
        {
            //the returing string should look like [[lat,long..],[long,lat..]]
            String querry = $"SELECT * FROM Puncte WHERE (";
            if (Latitudine != "")
                querry += $"Latitudine='{Latitudine}' AND ";
            if (Longitudine != "")
                querry += $"Longitudine='{Longitudine}' AND ";
            if (tip != "")
                querry += $"Tip='{tip}' AND ";
            if (User != "")
                querry += $"[User]='{User}' AND ";
            querry = querry.Remove(querry.Length - 5);
            querry += ")";
            Console.WriteLine(querry);
            SqlCommand cmd = new SqlCommand(querry,this.connection);
            var reader = cmd.ExecuteReader();
            List<String[]> response = new List<String[]>(); 
            while (reader.Read())
            {
                String[] row = new String[5];
                row[0] = reader.GetInt32(reader.GetOrdinal("Id")).ToString();
                row[1] = reader.GetString(reader.GetOrdinal("Latitudine"));
                row[2] = reader.GetString(reader.GetOrdinal("Longitudine"));
                row[3] = reader.GetString(reader.GetOrdinal("Tip"));
                row[4] = reader.GetString(reader.GetOrdinal("User"));
                response.Add(row);
            }
            return response;
        }
        
        public void connect()
        {
            this.connection.Open();
            if (this.connection == null)
            {
                Console.WriteLine("Nu s-a putut conecta la baza de date");
            }
        }

        public void disconnect()
        {
            if (this.connection != null)
            {
                this.connection.Close();
            }
        }

    }


}