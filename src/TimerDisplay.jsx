import React from 'react';

function TimerDisplay({ time, isRunning, isCountdown }) {
  const minutes = Math.floor(time / 60);
  const seconds = time % 60;

  const formattedTime = isCountdown 
    ? `${time}` 
    : `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;

  return (
    <div className={`timer-circle ${isRunning ? 'running' : ''} ${isCountdown ? 'countdown-phase' : ''}`}>
      {isCountdown && <div className="countdown-label">Meditation starts in...</div>}
      <div className="time-display">{formattedTime}</div>
    </div>
  );
}

export default TimerDisplay;
