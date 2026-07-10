package com.themoon.y1.adapters;

import android.view.KeyEvent;
import android.view.View;
import android.view.ViewGroup;
import android.widget.AbsListView;
import android.widget.BaseAdapter;
import android.widget.Button;

import com.themoon.y1.MainActivity;
import com.themoon.y1.ThemeManager;
import com.themoon.y1.models.SongItem;

import java.util.List;

public class SongListAdapter extends BaseAdapter {
    private List<SongItem> items;

    public SongListAdapter(List<SongItem> items) {
        this.items = items;
    }

    @Override
    public int getCount() { return items.size(); }

    @Override
    public Object getItem(int position) { return items.get(position); }

    @Override
    public long getItemId(int position) { return position; }

    @Override
    public View getView(final int position, View convertView, ViewGroup parent) {
        // 💡 이름은 btn으로 유지하여 기존 하위 코드와의 충돌을 막고, 타입은 범용적인 View로 바꿉니다!
        final android.view.View btn;
        final SongItem song = items.get(position);

        // 🚀 [유니코드 분기] 음악 모드(\uE03D)와 오디오북 모드(\uE86D)에 맞춘 유니코드 아이콘 장전
        String iconCode = MainActivity.instance.isAudiobookLibraryMode ? "\uE310" : "\uE405";

        // ==========================================
        // 🚀 [스마트 날짜 스탬프 엔진] '최근 추가된 곡' 모드일 때만 가동!
        // ==========================================
        String displayTitle = song.title; // 💡 기본은 원래 제목으로 장전

        // 🚨 [에러 완벽 방어막] private 변수 대신 누구나 볼 수 있는 public 변수(virtualQueryType)로 안전하게 검사합니다!
        if (MainActivity.instance != null && "RECENT".equals(MainActivity.instance.virtualQueryType)) {
            long lastMod = song.file.lastModified();

            // 1. 기기 시간 기준으로 '오늘 자정(00:00:00)'과 '어제 자정' 시간을 정확히 구합니다.
            java.util.Calendar cal = java.util.Calendar.getInstance();
            cal.set(java.util.Calendar.HOUR_OF_DAY, 0);
            cal.set(java.util.Calendar.MINUTE, 0);
            cal.set(java.util.Calendar.SECOND, 0);
            cal.set(java.util.Calendar.MILLISECOND, 0);
            long todayStart = cal.getTimeInMillis();
            long yesterdayStart = todayStart - (24 * 60 * 60 * 1000);

            String datePrefix = "";
            // 2. 시간표에 맞춰 다국어 번역 캡슐을 씌워 스탬프를 찍습니다!
            if (lastMod >= todayStart) {
                datePrefix = "[" + MainActivity.instance.t("Today") + "] "; // 오늘
            } else if (lastMod >= yesterdayStart) {
                datePrefix = "[" + MainActivity.instance.t("Yesterday") + "] "; // 어제
            } else {
                java.text.SimpleDateFormat sdf = new java.text.SimpleDateFormat("yy.MM.dd");
                datePrefix = "[" + sdf.format(new java.util.Date(lastMod)) + "] "; // 그 외 (ex: 26.07.10)
            }

            displayTitle = datePrefix + song.title; // 🎯 제목 앞에 스탬프를 찰칵! 합체시킵니다.
        }
        // ==========================================

        if (convertView == null) {
            // 🚀 1. 최초로 화면에 그릴 때는 유니코드 뷰 생성 엔진을 호출합니다!
            // 💡 [수정] song.title 대신, 스탬프가 찍혀있는 displayTitle 을 주입합니다!
            btn = MainActivity.instance.createListButtonWithIcon(iconCode, displayTitle);
            btn.setLayoutParams(new android.widget.AbsListView.LayoutParams(
                    android.widget.AbsListView.LayoutParams.MATCH_PARENT,
                    android.widget.AbsListView.LayoutParams.WRAP_CONTENT));
        } else {
            // 🚀 2. 스크롤을 내려서 기존 뷰를 재활용할 때
            btn = convertView;
            if (btn instanceof android.widget.LinearLayout) {
                android.widget.LinearLayout layout = (android.widget.LinearLayout) btn;
                // 레이아웃 안에 자식(아이콘, 텍스트)이 2개 이상 제대로 있다면?
                if (layout.getChildCount() > 1) {
                    android.widget.TextView tvIcon = (android.widget.TextView) layout.getChildAt(0);
                    android.widget.TextView tvText = (android.widget.TextView) layout.getChildAt(1);

                    // 💡 [수정] 재활용할 때도 스탬프가 찍혀있는 displayTitle 로 갈아끼웁니다!
                    tvIcon.setText(iconCode);
                    tvText.setText(displayTitle);
                }
            }
        }

        // 🚀 [버그 1의 핵심 해결책] 포커스가 이동할 때 프로그레스 바가 강제로 지워지는 현상을 원천 차단합니다.
        // (이하 코드 동일)


        // 🚀 [버그 1의 핵심 해결책] 포커스가 이동할 때 프로그레스 바가 강제로 지워지는 현상을 원천 차단합니다.
        if (MainActivity.instance.isAudiobookLibraryMode) {
            int pos = MainActivity.instance.prefs.getInt("book_pos_" + song.file.getAbsolutePath(), 0);
            int dur = MainActivity.instance.prefs.getInt("book_dur_" + song.file.getAbsolutePath(), 0);

            if (pos > 0 && dur > 0) {
                // 이어듣기 기록이 있는 오디오북 파일은 프로그레스 전용 포커스 유지 엔진으로 연결!
                MainActivity.instance.setupAudiobookProgress(btn, pos, dur);
            } else {
                // 재생 기록이 없는 순수 파일은 기본 포커스 리스너 할당
                applyDefaultFocusListener(btn, song.title);
            }
        } else {
            // 오디오북 모드가 아닌 일반 음악 모드일 때도 순정 포커스 리스너 할당
            applyDefaultFocusListener(btn, song.title);
        }

        // 짧은 클릭 리스너 (STATE_PLAYER로 화면 전환 및 재생)
        btn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                MainActivity.instance.clickFeedback();

                // 🚀 [정식 셔플 엔진 직결!] 어댑터가 불법으로 리스트를 조작하지 않고, 절대 셔플 엔진으로 리스트를 몽땅 던져줍니다!
                com.themoon.y1.managers.AudioPlayerManager.getInstance().playTrackList(MainActivity.instance.virtualSongList, position);

                // 플레이어 화면으로 전환
                MainActivity.instance.changeScreen(3); // 3: STATE_PLAYER
            }
        });

        // 롱 클릭 리스너 (즐겨찾기 해제 / M3U 플레이리스트 추가 등 통합 분기)
        btn.setOnLongClickListener(new View.OnLongClickListener() {
            @Override
            public boolean onLongClick(View v) {
                MainActivity.instance.clickFeedback();
                MainActivity.instance.isLongPressConsumed = true;

                if (MainActivity.instance.currentBrowserMode == 5) { // BROWSER_FAVORITES
                    MainActivity.instance.showRemoveFromFavoritesDialog(song.file);
                } else if (MainActivity.instance.currentBrowserMode == 7) { // BROWSER_M3U_SONGS
                    MainActivity.instance.showRemoveFromPlaylistDialog(song.file);
                } else {
                    MainActivity.instance.showAddToPlaylistDialog(song.file);
                }
                return true;
            }
        });

        return btn;
    }

    // 🚀 [신규] 유니코드 아이콘 뷰(LinearLayout)와 순정 버튼(Button)을 모두 지원하는 하이브리드 포커스 리스너!
    private void applyDefaultFocusListener(final android.view.View btn, final String title) {
        btn.setOnFocusChangeListener(new android.view.View.OnFocusChangeListener() {
            @Override
            public void onFocusChange(android.view.View v, boolean hasFocus) {
                if (hasFocus) {
                    btn.setBackground(MainActivity.instance.createButtonBackground(com.themoon.y1.ThemeManager.getListButtonFocusedBg()));

                    // 💡 유니코드 뷰(LinearLayout)일 경우 아이콘과 텍스트를 모두 포커스 색상으로 변경!
                    if (v instanceof android.widget.LinearLayout) {
                        android.widget.LinearLayout row = (android.widget.LinearLayout) v;
                        if (row.getChildCount() > 1) {
                            ((android.widget.TextView) row.getChildAt(0)).setTextColor(com.themoon.y1.ThemeManager.getListButtonFocusedTextColor());
                            ((android.widget.TextView) row.getChildAt(1)).setTextColor(com.themoon.y1.ThemeManager.getListButtonFocusedTextColor());
                        }
                    } else if (v instanceof android.widget.Button) {
                        ((android.widget.Button) v).setTextColor(com.themoon.y1.ThemeManager.getListButtonFocusedTextColor());
                    }

                    MainActivity.instance.showFastScrollLetter(title);
                } else {
                    btn.setBackground(MainActivity.instance.createButtonBackground(com.themoon.y1.ThemeManager.getListButtonNormalBg()));

                    // 💡 포커스가 벗어나면 원래 색상으로 복구!
                    if (v instanceof android.widget.LinearLayout) {
                        android.widget.LinearLayout row = (android.widget.LinearLayout) v;
                        if (row.getChildCount() > 1) {
                            ((android.widget.TextView) row.getChildAt(0)).setTextColor(com.themoon.y1.ThemeManager.getTextColorPrimary());
                            ((android.widget.TextView) row.getChildAt(1)).setTextColor(com.themoon.y1.ThemeManager.getTextColorPrimary());
                        }
                    } else if (v instanceof android.widget.Button) {
                        ((android.widget.Button) v).setTextColor(com.themoon.y1.ThemeManager.getTextColorPrimary());
                    }
                }
            }
        });
    }
}