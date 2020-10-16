# ルータから本体情報を取得（スクレイピング）する機能です
#
# 《環境作成》
#　 1) /var/www/SW_Cloud/scriptの配下に下記の2ファイルをコピー
# 　   rinf_get01.rb、rinf_get01.yml
# 　2) /var/www/SW_Cloud/scriptの配下にcsvディレクトリを作成
# 《動作手順》
#   1) /var/www/SW_Cloud/script/csvの配下に下記の2ファイルをコピー
#      ・3G.csv  ： 元ファイル：3G回線一覧（yyyy年mm月dd日現在)からリネーム
#      ・LTE.csv ： 元ファイル：LTE回線一覧(yyyy年mm月dd日現在)からリネーム
#   2) ruby rinf_get01.rbを実行
#      ・3G.csvから本体設定を取得  ： 引数に0を指定
#      ・LTE.csvから本体設定を取得 ： 引数に1を指定
# 《出力結果》
#   ・3G(LTE)out.csv ： ルータの本体設定の出力結果
#   ・3G(LTE)out.log ： ログファイル
#   ・ipaddr.txt　　 ： 3G(LTE).csvからIPアドレス列を抽出した中間ファイル

require 'yaml'
require 'fileutils'
require 'csv'
require 'mechanize'
require 'open-uri'
require 'nokogiri'
require 'pp'
require 'net/http'
require "date"


# ------------------------------------------------------------
# YAMLファイルの読み込み
# ------------------------------------------------------------
def get_yml

    $cfg = YAML.load_file("rinf_get01.yml")
end

# ------------------------------------------------------------
# 読込み元ファイルの存在チェック
# ------------------------------------------------------------
def chk_file(_iflg)

    if _iflg == 0
        _csvfil = $cfg["csv_3g_nm"]
    else
        _csvfil = $cfg["csv_lt_nm"]
    end

    if File.exist?("#{_csvfil}.csv") != true
        puts "#{_csvfil}.csv ファイルが存在しません"
        exit(0)
    end
end

# ------------------------------------------------------------
# ＣＳＶファイル→テキストファイル書き込み
# ------------------------------------------------------------
def get_csv(_iflg)

    if _iflg == 0
        _csvfil = $cfg["csv_3g_nm"]
    else
        _csvfil = $cfg["csv_lt_nm"]
    end

    #3G/LTE.csv（元ファイル）がUTF-8の場合、エンコードは不要
    #csv_data = CSV.read("#{_csvfil}.csv", headers: true, encoding: "Shift_JIS:UTF-8")
    csv_data = CSV.read("#{_csvfil}.csv", headers: true)

    File.open("./csv/ipaddr.txt", 'w') do |_f|
        csv_data.each do |data|
            _f.write("#{data[11]}\n")
        end
    end
end

# ------------------------------------------------------------
# ログファイルの書き込み
# ------------------------------------------------------------
def logging(_n, _ip, _outfil, _str)

    #_file = "csv/" + File.basename($PROGRAM_NAME,".*") 
    _file = _outfil
    _timn = Time.now
    _timf = _timn.strftime("%Y/%m/%d %H:%M:%S")
    _datn = Date.today

    #--------------------------------------------
    #ログファイルが存在していなければ新規作成
    #--------------------------------------------
    if File.exist?("#{_file}.log") == false
        File::open("#{_file}.log","w")
    end

    if File.mtime("#{_file}.log").month != _timn.month
        
        #--------------------------------------------
        # xxxx.log ⇒ xxxx.yyyymmにリネーム
        #--------------------------------------------
        File.rename("#{_file}.log","#{_file}.#{_datn.prev_month(1).year}" + format("%02d","#{_datn.prev_month(1).month}"))

        #--------------------------------------------
        # xxxx.yyyymm型のファイルをセット
        #--------------------------------------------
        _filal = Dir.entries("./csv").delete_if {|_f| (/^#{_file}\.(\d){6}$/ =~ _f).nil?}.sort

        #--------------------------------------------
        #過去3ヶ月以上のファイルは削除
        #--------------------------------------------
        _filal.reverse!.each_with_index { |_f,_i|
            File.delete(_f) if _i >= 3
        }
    end

    #--------------------------------------------
    #ログファイルの書込み
    #--------------------------------------------
    if _n.to_i == 1
        File::open("#{_file}.log","a") {|f| f.puts (" =====   start : #{_timf}   =====") }
    end
    File::open("#{_file}.log","a") {|f| f.puts ("#{_n} : #{_ip} : #{_str}") }

end

# ------------------------------------------------------------
# 本体設定を取得⇒アウトプットファイルに書込み
# ------------------------------------------------------------
def wrt_csv(_n, _ip, _iflg)

    begin
        
        #--------------------------------------------
        #Mechanizeのインスタンス化
        #--------------------------------------------
        agent = Mechanize.new
        agent.user_agent_alias = "Linux Firefox"
        agent.open_timeout = 10

        #_ip = "192.168.4.1"
        #_ip = "192.168.19.210"

        _ary = Array.new(10)										#配列の初期化
        _ary[0] = "#{_n}"
        _ary[1] = "#{_ip}" 
        
        if _iflg == 0
            _outfil = $cfg["csv_3g_out"]
        else
            _outfil = $cfg["csv_lt_out"]
        end

        agent.add_auth("http://#{_ip}:888", "admin", "sofinet")
        page_main = agent.get("http://#{_ip}:888")
        page_menu01 = agent.get("../cgi-bin/general.cgi")			#画面のright側

        #--------------------------------------------
        #本体設定の表示項目を取得
        #--------------------------------------------
        _m = 0
        page_menu01.search("td").each do |tag|
            if _m <= 6
                #puts tag.text
                _ary[_m + 2] = tag.text
            end
            _m += 1
        end

        #--------------------------------------------
        #本体設定の入力項目を取得	
        #--------------------------------------------
        _m = 0
        page_menu01.search("input").each do |tag|
            if _m == 1
                #puts tag['value']
                _ary[_m + 8] = tag['value']
            end
            _m += 1
        end
        
        #--------------------------------------------
        #ＣＳＶファイル書き込み（a:追加）
        #--------------------------------------------
        _filout = CSV.open("#{_outfil}.csv",'a')
            _filout.puts _ary
        _filout.close
        
        p "#{_n} : #{_ip} : OK"
        logging(_n, _ip, _outfil, "OK")
        
    rescue => e
        p "#{_n} : #{_ip} : Err"
        logging(_n, _ip, _outfil, e.message)
    end
end

# ------------------------------------------------------------
# テキストファイルを１件つづ読み込む
# ------------------------------------------------------------
def get_txt(_iflg)

    if _iflg == 0
        _outfil = $cfg["csv_3g_out"]
    else
        _outfil = $cfg["csv_lt_out"]
    end

    #--------------------------------------------
    #アウトプットファイルの初期化
    #--------------------------------------------
    if File.exist?("#{_outfil}.csv")
        File.delete("#{_outfil}.csv")
    end
    File::open("#{_outfil}.csv","w")

    _n=0
    _filinp = File.open('./csv/ipaddr.txt', 'r:utf-8') do |f|
        f.each_line do |line|
            _n += 1
            _ip = line.chomp
            wrt_csv(_n, _ip, _iflg)
        end
    end
end

###################################################

if ARGV[0].nil?
    puts "第１引数を指定して下さい"
    exit(0)
end

if ARGV[0].to_s == "0" || ARGV[0].to_s == "1"
else
    puts "第１引数には「0:3G」または「1:LTE」を指定して下さい"
    exit(0)
end

# Linuxへのコマンド（環境変数を削除）
`unset http_proxy`

#-------------------------------------------------
# YAMLファイルの読み込み
#-------------------------------------------------
get_yml
#p "get_yml  ==> OK"

#-------------------------------------------------
# 読込み元ファイルの存在チェック
#-------------------------------------------------
chk_file(ARGV[0].to_i)
#p "chk_file ==> OK"

#-------------------------------------------------
# ＣＳＶファイル→テキストファイル書き込み
#-------------------------------------------------
get_csv(ARGV[0].to_i)
#p "get_csv  ==> OK"

#-------------------------------------------------
# テキストファイルを１件つづ読み込む
#-------------------------------------------------
get_txt(ARGV[0].to_i)
#p "get_txt  ==> OK"
