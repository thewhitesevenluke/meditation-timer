import { useState, useEffect } from 'react';
import './App.css';
import TimerDisplay from './TimerDisplay';

// Persistent Web Audio variables to prevent garbage collection and reload across renders
let audioCtx = null;
let startBuffer = null;
let tingshaBuffer = null;

function App() {
  const [totalTime, setTotalTime] = useState(15 * 60); // 15 minutes default in seconds
  const [timeLeft, setTimeLeft] = useState(15 * 60);
  const [isRunning, setIsRunning] = useState(false);
  
  // Interval X in seconds (default is half of totalTime)
  const [intervalX, setIntervalX] = useState(7.5 * 60); 
  const [isCustomInterval, setIsCustomInterval] = useState(false);
  const [showSettings, setShowSettings] = useState(false);

  // Local text input states to allow precise, raw editing of minutes and seconds separately
  const [totalTimeMinsInput, setTotalTimeMinsInput] = useState("15");
  const [totalTimeSecsInput, setTotalTimeSecsInput] = useState("00");
  const [intervalMinsInput, setIntervalMinsInput] = useState("7");
  const [intervalSecsInput, setIntervalSecsInput] = useState("30");
  const [intervalCountInput, setIntervalCountInput] = useState("2");
  const [intervalSound, setIntervalSound] = useState('tingsha');
  const [intervalPitch, setIntervalPitch] = useState(0.85);

  // Preparation Countdown States
  const [isCountdownEnabled, setIsCountdownEnabled] = useState(false);
  const [countdownDuration, setCountdownDuration] = useState(10);
  const [countdownActive, setCountdownActive] = useState(false);
  const [countdownTimeLeft, setCountdownTimeLeft] = useState(10);
  const [countdownDurationInput, setCountdownDurationInput] = useState("10");

  // Format seconds to a readable "Xm Ys" or "Ys" format
  const formatMinutesAndSeconds = (totalSeconds) => {
    const mins = Math.floor(totalSeconds / 60);
    const secs = Math.round(totalSeconds % 60);
    if (mins > 0 && secs > 0) {
      return `${mins}m ${secs}s`;
    } else if (mins > 0) {
      return `${mins}m`;
    } else {
      return `${secs}s`;
    }
  };

  // Synchronize input fields with active state only when they differ parsed-wise,
  // preventing user's custom keyboard typing from being wiped out or cursor jumped
  useEffect(() => {
    const mins = Math.floor(totalTime / 60);
    const secs = totalTime % 60;
    
    if (parseInt(totalTimeMinsInput) !== mins) {
      setTotalTimeMinsInput(mins.toString());
    }
    if (parseInt(totalTimeSecsInput) !== secs) {
      setTotalTimeSecsInput(secs.toString().padStart(2, '0'));
    }
  }, [totalTime]);

  useEffect(() => {
    const mins = Math.floor(intervalX / 60);
    const secs = intervalX % 60;
    
    if (parseInt(intervalMinsInput) !== mins) {
      setIntervalMinsInput(mins.toString());
    }
    if (parseInt(intervalSecsInput) !== secs) {
      setIntervalSecsInput(secs.toString().padStart(2, '0'));
    }
  }, [intervalX]);

  useEffect(() => {
    const count = intervalX > 0 ? Math.round(totalTime / intervalX) : 1;
    if (parseInt(intervalCountInput) !== count) {
      setIntervalCountInput(count.toString());
    }
  }, [intervalX, totalTime]);

  useEffect(() => {
    if (parseInt(countdownDurationInput) !== countdownDuration) {
      setCountdownDurationInput(countdownDuration.toString());
    }
  }, [countdownDuration]);

  // Load and decode the authentic meditation audio files at startup
  useEffect(() => {
    const initAudioEngine = async () => {
      try {
        if (!audioCtx) {
          audioCtx = new (window.AudioContext || window.webkitAudioContext)();
        }

        if (!startBuffer) {
          const startRes = await fetch('/start.mp3');
          const startArrayBuffer = await startRes.arrayBuffer();
          audioCtx.decodeAudioData(startArrayBuffer)
            .then(decoded => {
              startBuffer = decoded;
            })
            .catch(err => console.error("Error decoding start.mp3", err));
        }

        if (!tingshaBuffer) {
          const tingshaRes = await fetch('/tingsha3.mp3');
          const tingshaArrayBuffer = await tingshaRes.arrayBuffer();
          audioCtx.decodeAudioData(tingshaArrayBuffer)
            .then(decoded => {
              tingshaBuffer = decoded;
            })
            .catch(err => console.error("Error decoding tingsha3.mp3", err));
        }
      } catch (e) {
        console.warn("Failed to initialize Web Audio engine at startup:", e);
      }
    };
    initAudioEngine();
  }, []);

  const playBuffer = (buffer, rate = 1.0, volumeMultiplier = 1.8, isBowl = true) => {
    try {
      if (!audioCtx) {
        audioCtx = new (window.AudioContext || window.webkitAudioContext)();
      }

      if (audioCtx.state === 'suspended') {
        audioCtx.resume();
      }

      if (!buffer) {
        console.warn("Audio buffer not loaded yet. Falling back to HTML5 Audio.");
        const audioPath = isBowl ? '/start.mp3' : '/tingsha3.mp3';
        const fallbackAudio = new Audio(audioPath);
        fallbackAudio.playbackRate = rate;
        fallbackAudio.volume = Math.min(1.0, volumeMultiplier * 0.5);
        fallbackAudio.play().catch(e => console.warn("HTML5 fallback playback failed:", e));
        return;
      }

      const source = audioCtx.createBufferSource();
      source.buffer = buffer;
      source.playbackRate.value = rate;

      const gainNode = audioCtx.createGain();
      gainNode.gain.setValueAtTime(volumeMultiplier, audioCtx.currentTime);

      source.connect(gainNode);
      gainNode.connect(audioCtx.destination);
      source.start(0);
    } catch (e) {
      console.warn("Failed to play audio buffer:", e);
    }
  };

  // Play the deep Tibetan bowl gong (rate 0.8, volume 1.4 for smooth, resonant volume)
  const playGong = () => {
    playBuffer(startBuffer, 0.8, 1.4, true);
  };

  // Play the calm, lower-pitched accent chime at interval marks (supports custom selections)
  const playIntervalGong = (soundType = intervalSound, pitchRate = intervalPitch) => {
    const buffer = soundType === 'bowl' ? startBuffer : tingshaBuffer;
    playBuffer(buffer, pitchRate, 1.4, soundType === 'bowl');
  };

  const playEndGong = () => {
    playGong();
    setTimeout(() => {
      playGong();
    }, 1500); // Exquisite overlapping dual-bowl chime
  };

  useEffect(() => {
    let interval = null;
    if (isRunning) {
      if (countdownActive) {
        interval = setInterval(() => {
          setCountdownTimeLeft((prev) => {
            if (prev <= 1) {
              setCountdownActive(false);
              playGong();
              return 0;
            }
            return prev - 1;
          });
        }, 1000);
      } else if (timeLeft > 0) {
        interval = setInterval(() => {
          setTimeLeft((prev) => {
            const nextTimeLeft = prev - 1;
            const elapsed = totalTime - nextTimeLeft;
            
            // Play high chime gong at interval
            if (elapsed > 0 && nextTimeLeft > 0 && elapsed % intervalX === 0) {
              playIntervalGong();
            }
            
            // Play end double deep gong
            if (nextTimeLeft === 0) {
              playEndGong();
              setIsRunning(false);
            }
            
            return nextTimeLeft;
          });
        }, 1000);
      }
    }
    return () => clearInterval(interval);
  }, [isRunning, countdownActive, totalTime, intervalX]);

  const toggleTimer = () => {
    if (!isRunning) {
      // Start or resume
      if (timeLeft === totalTime && !countdownActive) {
        if (isCountdownEnabled) {
          setCountdownActive(true);
          setCountdownTimeLeft(countdownDuration);
        } else {
          playGong();
        }
      }
      setIsRunning(true);
    } else {
      // Pause
      setIsRunning(false);
    }
  };

  const resetTimer = () => {
    setIsRunning(false);
    setCountdownActive(false);
    setTimeLeft(totalTime);
  };

  // Keyboard typing handlers for Total Time minutes and seconds
  const handleTotalMinsInputChange = (valStr) => {
    if (/^\d*$/.test(valStr)) {
      setTotalTimeMinsInput(valStr);
      
      const mins = valStr === "" ? 0 : parseInt(valStr);
      const secs = totalTimeSecsInput === "" ? 0 : parseInt(totalTimeSecsInput);
      const newTotal = mins * 60 + secs;
      
      if (newTotal >= 5) {
        const capped = Math.min(10800, newTotal); // Cap at 180 mins
        setTotalTime(capped);
        setTimeLeft(capped);
        setIsRunning(false);
        
        if (!isCustomInterval) {
          setIntervalX(Math.round(capped / 2));
        } else if (intervalX > capped) {
          setIntervalX(capped);
        }
      }
    }
  };

  const handleTotalSecsInputChange = (valStr) => {
    if (/^\d*$/.test(valStr)) {
      let cleaned = valStr;
      if (valStr !== "") {
        const parsedSecs = parseInt(valStr);
        if (parsedSecs > 59) {
          cleaned = "59";
        }
      }
      setTotalTimeSecsInput(cleaned);
      
      const mins = totalTimeMinsInput === "" ? 0 : parseInt(totalTimeMinsInput);
      const secs = cleaned === "" ? 0 : parseInt(cleaned);
      const newTotal = mins * 60 + secs;
      
      if (newTotal >= 5) {
        const capped = Math.min(10800, newTotal);
        setTotalTime(capped);
        setTimeLeft(capped);
        setIsRunning(false);
        
        if (!isCustomInterval) {
          setIntervalX(Math.round(capped / 2));
        } else if (intervalX > capped) {
          setIntervalX(capped);
        }
      }
    }
  };

  const handleTotalTimeInputBlur = () => {
    const mins = totalTimeMinsInput === "" ? 0 : parseInt(totalTimeMinsInput);
    const secs = totalTimeSecsInput === "" ? 0 : parseInt(totalTimeSecsInput);
    const total = mins * 60 + secs;
    
    if (total < 5) {
      // Revert to safe minimum of 5 seconds if left blank or too low
      const fallback = 5;
      setTotalTime(fallback);
      setTimeLeft(fallback);
      setTotalTimeMinsInput("0");
      setTotalTimeSecsInput("05");
      if (!isCustomInterval) {
        setIntervalX(3);
      }
    } else {
      const capped = Math.min(10800, total);
      setTotalTime(capped);
      setTimeLeft(capped);
      
      const finalMins = Math.floor(capped / 60);
      const finalSecs = capped % 60;
      setTotalTimeMinsInput(finalMins.toString());
      setTotalTimeSecsInput(finalSecs.toString().padStart(2, '0'));
    }
  };

  // Keyboard typing handlers for Gong Interval minutes and seconds
  const handleIntervalMinsInputChange = (valStr) => {
    if (/^\d*$/.test(valStr)) {
      setIntervalMinsInput(valStr);
      
      const mins = valStr === "" ? 0 : parseInt(valStr);
      const secs = intervalSecsInput === "" ? 0 : parseInt(intervalSecsInput);
      const newTotal = mins * 60 + secs;
      
      if (newTotal >= 5 && newTotal <= totalTime) {
        setIntervalX(newTotal);
        setIsCustomInterval(true);
        setIsRunning(false);
        setTimeLeft(totalTime);
      }
    }
  };

  const handleIntervalSecsInputChange = (valStr) => {
    if (/^\d*$/.test(valStr)) {
      let cleaned = valStr;
      if (valStr !== "") {
        const parsedSecs = parseInt(valStr);
        if (parsedSecs > 59) {
          cleaned = "59";
        }
      }
      setIntervalSecsInput(cleaned);
      
      const mins = intervalMinsInput === "" ? 0 : parseInt(intervalMinsInput);
      const secs = cleaned === "" ? 0 : parseInt(cleaned);
      const newTotal = mins * 60 + secs;
      
      if (newTotal >= 5 && newTotal <= totalTime) {
        setIntervalX(newTotal);
        setIsCustomInterval(true);
        setIsRunning(false);
        setTimeLeft(totalTime);
      }
    }
  };

  const handleIntervalInputBlur = () => {
    const mins = intervalMinsInput === "" ? 0 : parseInt(intervalMinsInput);
    const secs = intervalSecsInput === "" ? 0 : parseInt(intervalSecsInput);
    const total = mins * 60 + secs;
    
    if (total < 5 || total > totalTime) {
      // Revert to current saved state
      const finalMins = Math.floor(intervalX / 60);
      const finalSecs = intervalX % 60;
      setIntervalMinsInput(finalMins.toString());
      setIntervalSecsInput(finalSecs.toString().padStart(2, '0'));
    } else {
      setIntervalX(total);
      
      const finalMins = Math.floor(total / 60);
      const finalSecs = total % 60;
      setIntervalMinsInput(finalMins.toString());
      setIntervalSecsInput(finalSecs.toString().padStart(2, '0'));
    }
  };

  const handleIntervalCountInputChange = (valStr) => {
    if (/^\d*$/.test(valStr)) {
      setIntervalCountInput(valStr);
      
      const count = valStr === "" ? 0 : parseInt(valStr);
      if (count >= 1) {
        let calculated = Math.round(totalTime / count);
        calculated = Math.max(5, Math.min(totalTime, calculated));
        
        setIntervalX(calculated);
        setIsCustomInterval(true);
        setIsRunning(false);
        setTimeLeft(totalTime);
      }
    }
  };

  const handleIntervalCountInputBlur = () => {
    const count = intervalCountInput === "" ? 0 : parseInt(intervalCountInput);
    if (count < 1) {
      const activeCount = intervalX > 0 ? Math.round(totalTime / intervalX) : 2;
      setIntervalCountInput(activeCount.toString());
    } else {
      let calculated = Math.round(totalTime / count);
      calculated = Math.max(5, Math.min(totalTime, calculated));
      setIntervalX(calculated);
      
      const finalCount = Math.round(totalTime / calculated);
      setIntervalCountInput(finalCount.toString());
    }
  };

  const handleCountdownDurationInputChange = (valStr) => {
    if (/^\d*$/.test(valStr)) {
      setCountdownDurationInput(valStr);
      
      const parsed = valStr === "" ? 0 : parseInt(valStr);
      if (parsed >= 3 && parsed <= 300) {
        setCountdownDuration(parsed);
      }
    }
  };

  const handleCountdownDurationInputBlur = () => {
    const parsed = countdownDurationInput === "" ? 0 : parseInt(countdownDurationInput);
    if (parsed < 3) {
      setCountdownDuration(3);
      setCountdownDurationInput("3");
    } else if (parsed > 300) {
      setCountdownDuration(300);
      setCountdownDurationInput("300");
    } else {
      setCountdownDuration(parsed);
      setCountdownDurationInput(parsed.toString());
    }
  };

  const resetToAutoInterval = () => {
    setIsCustomInterval(false);
    const half = Math.round(totalTime / 2);
    setIntervalX(half);
    setIsRunning(false);
    setTimeLeft(totalTime);
  };

  return (
    <div className="app-container">
      <h1 className="title">Spring Meditation</h1>
      
      {/* Circular Timer Display */}
      <TimerDisplay 
        time={countdownActive ? countdownTimeLeft : timeLeft} 
        isRunning={isRunning || countdownActive} 
        isCountdown={countdownActive} 
      />

      {/* Bottom Section - Contains Controls & Settings Popup */}
      <div className="bottom-section">
        <div className="controls">
          <button className="btn primary" onClick={toggleTimer}>
            {isRunning ? 'Pause' : 'Start'}
          </button>
          <button className="btn" onClick={resetTimer}>
            Reset
          </button>
          <button 
            className={`btn settings-toggle-btn ${showSettings ? 'active' : ''}`} 
            onClick={() => setShowSettings(!showSettings)}
          >
            Settings
          </button>
        </div>

        {showSettings && (
          <div className="settings-panel">
            <h3 className="settings-title">Session Settings</h3>
            
            {/* Total Duration Slider & Direct Input Option */}
            <div className="setting-row">
              <div className="setting-label">
                <span>Meditation Time:</span>
                <div className="input-group">
                  <div className="input-container">
                    <input 
                      type="text" 
                      pattern="[0-9]*"
                      value={totalTimeMinsInput} 
                      onChange={(e) => handleTotalMinsInputChange(e.target.value)}
                      onBlur={handleTotalTimeInputBlur}
                      className="time-number-input"
                    />
                    <span className="input-suffix">m</span>
                  </div>
                  <div className="input-container">
                    <input 
                      type="text" 
                      pattern="[0-9]*"
                      value={totalTimeSecsInput} 
                      onChange={(e) => handleTotalSecsInputChange(e.target.value)}
                      onBlur={handleTotalTimeInputBlur}
                      className="time-number-input"
                    />
                    <span className="input-suffix">s</span>
                  </div>
                </div>
              </div>
              <input 
                type="range" 
                min="10" 
                max="5400" 
                step="10"
                value={totalTime} 
                onChange={(e) => {
                  const val = parseInt(e.target.value) || 10;
                  setTotalTime(val);
                  setTimeLeft(val);
                  setIsRunning(false);
                  if (!isCustomInterval) {
                    setIntervalX(Math.round(val / 2));
                  } else if (intervalX > val) {
                    setIntervalX(val);
                  }
                }}
                className="setting-slider"
              />
            </div>

            {/* Interval Gong Slider & Direct Input Option */}
            <div className="setting-row">
              <div className="setting-label">
                <span>Gong Interval:</span>
                <div className="input-group">
                  <div className="input-container">
                    <input 
                      type="text" 
                      pattern="[0-9]*"
                      value={intervalMinsInput} 
                      onChange={(e) => handleIntervalMinsInputChange(e.target.value)}
                      onBlur={handleIntervalInputBlur}
                      className="time-number-input"
                    />
                    <span className="input-suffix">m</span>
                  </div>
                  <div className="input-container">
                    <input 
                      type="text" 
                      pattern="[0-9]*"
                      value={intervalSecsInput} 
                      onChange={(e) => handleIntervalSecsInputChange(e.target.value)}
                      onBlur={handleIntervalInputBlur}
                      className="time-number-input"
                    />
                    <span className="input-suffix">s</span>
                  </div>
                </div>
              </div>
              <input 
                type="range" 
                min="5" 
                max={totalTime} 
                step="5"
                value={intervalX} 
                onChange={(e) => {
                  const val = parseInt(e.target.value) || 5;
                  setIntervalX(val);
                  setIsCustomInterval(true);
                  setIsRunning(false);
                  setTimeLeft(totalTime);
                }}
                className="setting-slider"
              />
              
              <div className="interval-calc-row">
                <span>Or divide session into:</span>
                <div className="input-group">
                  <div className="input-container">
                    <input 
                      type="text" 
                      pattern="[0-9]*"
                      value={intervalCountInput} 
                      onChange={(e) => handleIntervalCountInputChange(e.target.value)}
                      onBlur={handleIntervalCountInputBlur}
                      className="time-number-input"
                      style={{ width: '32px', textAlign: 'center' }}
                    />
                    <span className="input-suffix">gongs</span>
                  </div>
                </div>
              </div>
            </div>

            {/* Reset to Half-Time auto helper */}
            {isCustomInterval && (
              <button className="reset-auto-btn" onClick={resetToAutoInterval}>
                Reset Gong to Half-Time ({formatMinutesAndSeconds(totalTime / 2)})
              </button>
            )}

            {/* Interval Sound Choice */}
            <div className="setting-row">
              <div className="setting-label">
                <span>Interval Bell Sound:</span>
                <div className="sound-toggle-group">
                  <button 
                    type="button"
                    className={`sound-toggle-btn ${intervalSound === 'bowl' ? 'active' : ''}`}
                    onClick={() => {
                      setIntervalSound('bowl');
                      playIntervalGong('bowl', intervalPitch);
                    }}
                  >
                    Bowl
                  </button>
                  <button 
                    type="button"
                    className={`sound-toggle-btn ${intervalSound === 'tingsha' ? 'active' : ''}`}
                    onClick={() => {
                      setIntervalSound('tingsha');
                      playIntervalGong('tingsha', intervalPitch);
                    }}
                  >
                    Tingsha
                  </button>
                </div>
              </div>
            </div>

            {/* Bell Tone (Pitch) Slider */}
            <div className="setting-row">
              <div className="setting-label">
                <span>Interval Bell Pitch:</span>
                <span className="pitch-label">{intervalPitch < 0.75 ? 'Deep' : intervalPitch > 1.05 ? 'High' : 'Warm'} ({intervalPitch.toFixed(2)}x)</span>
              </div>
              <input 
                type="range" 
                min="0.5" 
                max="1.5" 
                step="0.05"
                value={intervalPitch} 
                onChange={(e) => {
                  const val = parseFloat(e.target.value);
                  setIntervalPitch(val);
                }}
                onMouseUp={() => playIntervalGong(intervalSound, intervalPitch)}
                onTouchEnd={() => playIntervalGong(intervalSound, intervalPitch)}
                className="setting-slider"
              />
            </div>

            {/* Preparation Countdown Switch & Slider */}
            <div className="setting-row">
              <div className="setting-label">
                <span>Preparation Countdown:</span>
                <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                  {isCountdownEnabled && (
                    <div className="input-container">
                      <input 
                        type="text" 
                        pattern="[0-9]*"
                        value={countdownDurationInput} 
                        onChange={(e) => handleCountdownDurationInputChange(e.target.value)}
                        onBlur={handleCountdownDurationInputBlur}
                        className="time-number-input"
                      />
                      <span className="input-suffix">s</span>
                    </div>
                  )}
                  <label className="switch-container">
                    <input 
                      type="checkbox" 
                      className="switch-input" 
                      checked={isCountdownEnabled}
                      onChange={(e) => setIsCountdownEnabled(e.target.checked)}
                    />
                    <span className="switch-slider"></span>
                  </label>
                </div>
              </div>
              {isCountdownEnabled && (
                <input 
                  type="range" 
                  min="5" 
                  max="60" 
                  step="1"
                  value={countdownDuration} 
                  onChange={(e) => {
                    const val = parseInt(e.target.value) || 5;
                    setCountdownDuration(val);
                    setCountdownDurationInput(val.toString());
                  }}
                  className="setting-slider"
                />
              )}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

export default App;
