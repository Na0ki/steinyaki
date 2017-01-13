# -*- coding: utf-8 -*-
require 'yaml'

# 後々の拡張の可能性も考えて、あひる焼くなプラグインとほぼ同じ構造にしている
Plugin.create(:steinyaki) do

  stein = ['ｳﾞｪﾝﾃﾞﾙｼｭﾀｲﾝ焼き']

  def prepare
    begin
      @dictionary = Hash.new
      dictionaries = Dir.glob("#{File.join(__dir__, 'dictionary')}/*.yml")
      dictionaries.each { |d| @dictionary[File.basename(d, '.*')] = YAML.load_file(d) }
      @user_list = YAML.load_file(File.join(__dir__, 'user_list.yml'))
      @defined_time = Time.new.freeze
    rescue LoadError => e
      error e
      Service.primary.post(:message => '辞書の更新時にエラーが発生しました: %{time}' % {time: Time.now.to_s}, :replyto => Service.primary.user)
    end
  end


  def sample(key)
    @dictionary.values_at(key)[0].sample
  end


  def select_reply(msg, time)
    return sample('stein')
  end

  prepare


  filter_filter_stream_track do |watching|
    [(watching.split(','.freeze) + stein).join(',')]
  end


  on_appear do |ms|
    ms.each do |m|
      # メッセージ生成時刻が起動前またはリツイートならば次のループへ
      next if m[:created] < @defined_time or m.retweet?

      p m.user
      p m.user[:id]
      p @user_list

      if m.to_s =~ Regexp.union(stein) and @user_list.include?(m.user[:id].to_s)
        # select reply dic & send reply & fav
        reply = select_reply(m.to_s, Time.now)
        Service.primary.post(:message => '@%{id} %{reply}' % {id: m.user.idname, reply: reply}, :replyto => m)
        m.favorite(true)
      end

      if m.to_s =~ /ｳﾞｪﾝﾃﾞﾙｼｭﾀｲﾝ更新/ and m.user.idname == Service.primary.user
        prepare
        Service.primary.post(:message => '[ｳﾞｪﾝﾃﾞﾙｼｭﾀｲﾝ] 辞書の更新が完了しました: %{time}' % {time: Time.now.to_s}, :replyto => m)
      end

    end
  end
end
