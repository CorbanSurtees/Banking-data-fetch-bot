require "open-uri"
require "fileutils"
require "date"
require "csv"

SQL_DIR = File.expand_path("../../3/sql", __dir__)

def download(url, dest)
  open(url) do |u|
    File.open(dest, "wb") { |f| f.write(u.read) }
  end
  puts "Downloaded #{dest}"
end

def convert_csv_to_txt_dos(input_csv, output_txt)
  # Convert CSV to TXT with DOS line endings (CRLF)
  File.open(output_txt, "wb") do |out|
    CSV.foreach(input_csv) do |row|
      out.write(row.join("\t") + "\r\n")  # <-- CRLF here
    end
  end
end

def latest_nz_bank_branch_register
  url = "https://www.paymentsnz.co.nz/resources/industry-registers/bank-branch-register/download/csv/"
  today = Date.today.strftime("%Y%m")
  # Download as CSV first
  csv_download = File.join(SQL_DIR, "BankBranchRegister.csv")
  download(url, csv_download)
  # Convert CSV to tab-delimited .txt
  dest = File.join(SQL_DIR, "BankBranchRegister.txt")
  convert_csv_to_tab_delimited(csv_download, dest)
  # Remove temporary CSV file
end

def convert_csv_to_tab_delimited(input_csv, output_txt)
  File.open(output_txt, "w") do |out|
    CSV.foreach(input_csv) do |row|
      out.puts row.join("\t")
    end
  end
end

def latest_au_bsb_key
  url = "https://auspaynetbsbpublic.blob.core.windows.net/bsb-reports/key%20to%20abbreviations%20and%20bsb%20numbers.csv"
  today = Date.today.strftime("%Y%m%d")
  dest = File.join(SQL_DIR, "BSBKey.csv")
  download(url, dest)
  convert_csv_to_txt_dos(dest, dest)
end

def latest_au_bsb_directory
  url = "https://auspaynetbsbpublic.blob.core.windows.net/bsb-reports/BSBDirectoryFull.csv"
  today = Date.today.strftime("%Y%m%d")
  dest = File.join(SQL_DIR, "BSBDirectory.csv")
  download(url, dest)
end

def latest_timezone_data
  url = "https://ftp.iana.org/tz/tzdata-latest.tar.gz"
  tar_dest = File.join(SQL_DIR, "tzdata-latest.tar.gz")
  download(url, tar_dest)
  # Extract zone.tab
  if system("tar -xzf #{tar_dest} -C #{SQL_DIR} zone.tab")
    puts "Extracted zone.tab to #{SQL_DIR}"
  else
    puts "Failed to extract zone.tab from #{tar_dest}"
  end
  File.delete(tar_dest) if File.exist?(tar_dest)
end

def convert_nz_banks_csv(input_path, output_path)
  # Use awk command to process tab-delimited file
  cmd = "awk -F'\\t' 'NR > 1 { printf \"NZ,%s,\\\"%s\\\"\\n\", $1, $5 }' \"#{input_path}\" | sort -u > \"#{output_path}\""
  if system(cmd)
    puts "Converted to #{output_path}"
  else
    puts "Failed to convert #{input_path} using awk command"
  end
end

FileUtils.mkdir_p(SQL_DIR)

puts "Updating NZ Bank Branch Register..."
latest_nz_bank_branch_register

puts "Updating AU BSB Key..."
latest_au_bsb_key

puts "Updating AU BSB Directory..."
latest_au_bsb_directory

puts "Updating Timezone Data..."
latest_timezone_data

# Always run NZ bank conversion after downloads
files = Dir[File.join(SQL_DIR, "BankBranchRegister-*.txt")]
if files.any?
  input = files.max
  output = File.join(SQL_DIR, "nz_banks.csv")
  convert_nz_banks_csv(input, output)
else
  puts "No BankBranchRegister-*.txt file found in #{SQL_DIR} for conversion"
end

puts "All downloads and conversions complete."
