require "open-uri"
require "fileutils"
require "date"
require "csv"

SQL_DIR = File.expand_path("./3/sql", __dir__)

def download(url, dest)
  URI.open(url) do |u|
    File.open(dest, "wb") { |f| f.write(u.read) }
  end
  puts "Downloaded #{dest}"
end

def latest_nz_bank_branch_register
  url = "https://www.paymentsnz.co.nz/resources/industry-registers/bank-branch-register/download/csv/"
  today = Date.today.strftime("%Y%m")
  dest = File.join(SQL_DIR, "BankBranchRegister-#{today}.txt")
  download(url, dest)
end

def latest_au_bsb_key
  url = "https://auspaynetbsbpublic.blob.core.windows.net/bsb-reports/key%20to%20abbreviations%20and%20bsb%20numbers.csv"
  today = Date.today.strftime("%Y%m%d")
  dest = File.join(SQL_DIR, "BSBKey-#{today}.csv")
  download(url, dest)
end

def latest_au_bsb_directory
  url = "https://auspaynetbsbpublic.blob.core.windows.net/bsb-reports/BSBDirectoryFull.csv"
  today = Date.today.strftime("%Y%m%d")
  dest = File.join(SQL_DIR, "BSBDirectory-#{today}.csv")
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
  rows = []
  CSV.foreach(input_path, headers: true) do |row|
    bank_number = row["Bank_Number"] || row[0]
    bank_name = row["Bank_Name"] || row[4]
    rows << ["NZ", bank_number, "\"#{bank_name}\""]
  end
  rows.uniq!
  rows.sort_by! { |r| r[1] }
  File.open(output_path, "w") do |f|
    rows.each { |r| f.puts r.join(",") }
  end
  puts "Converted to #{output_path}"
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
