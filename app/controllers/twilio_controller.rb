# -*- coding: utf-8 -*-
require "twilio-ruby"

class TwilioController < ApplicationController
  include Webhookable

  after_filter :set_header

  skip_before_action :verify_authenticity_token

  def welcome
    response = Twilio::TwiML::Response.new do |r|
      r.Say <<"EOS", language: "ja-jp"
お電話ありがとうございます。
この電話番号にて新郎新婦へ送るメッセージを承ります。
頂戴したメッセージは、披露宴にて２人にプレゼントいたします。
それまでは、２人には内緒にしておいてください。
また、皆様から頂いたエピソードの中から披露宴で是非紹介したい
と思ったものについては、後日今お電話頂いている番号あてに
ご連絡する可能性があることをご了承下さい。
EOS
      # -MEMO-
      # 音声ファイルを再生したい場合は次のようにする。
      # r.Play AUDIO_FILE_URL
      r.Redirect "/record", method: "get"
    end

    render_twiml response
  end

  def record
    response = Twilio::TwiML::Response.new do |r|
      r.Say <<"EOS", language: "ja-jp"
それでは、新郎新婦にお届けするお祝いメッセージを
発信オンの後に続いて、60秒以内でお話ください。
完了したらシャープを押してください。準備はよろしいですか？
最初にお名前をお願いいたします。それではどうぞ！
EOS
      r.Record maxLength: 60, action: "/recorded", method: "post", timeout: 15
    end

    render_twiml response
  end

  def recorded
    begin
      raise ArgumentError unless params[:RecordingSid]
      record = Record.new(recording_url: params[:RecordingUrl],
                          from: params[:From],
                          note: 'Created')
      record.save
      redirect_to "/confirm/#{record.id}"
    rescue Exception => e
      redirect_to "/confirmed"
    end
  end

  def confirm
    record = Record.find_by(id: params[:id].to_i)
    response = Twilio::TwiML::Response.new do |r|
      r.Gather action: "/respond_to_confirm/#{record.id}", method: "post", numDigits: 1, timeout: 10 do |g|
        g.Say <<"EOS", language: "ja-jp"
いただいたメッセージを再生します。
EOS
        g.Play record.recording_url
        g.Say <<"EOS", language: "ja-jp"
このメッセージをお届けしてよろしければ、数字の1を
もう一度録音する場合は、数字の3を押してください。
EOS
      end
      r.Redirect "/confirm/#{params[:id]}", method: "get"
    end

    render_twiml response
  end

  def respond_to_confirm
    record = Record.find_by(id: params[:id].to_i)
    case params[:Digits]
    when "3","2"
      record.note = "Rejected"
      record.save
      redirect_to "/record"
    when "1"
      record.note = "Confirmed"
      record.save
      redirect_to "/confirmed"
    else
      redirect_to "/confirm/#{record.id}"
    end
  end

  def confirmed
    response = Twilio::TwiML::Response.new do |r|
      r.Say <<"EOS", language: "ja-jp"
"メッセージを承りました。お電話ありがとうございました。"
EOS
    end

    render_twiml response
  end
end
