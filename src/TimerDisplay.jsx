import React from 'react';

function TimerDisplay({ time, isRunning, isCountdown }) {
  const roundedTime = Math.round(time);
  const minutes = Math.floor(roundedTime / 60);
  const seconds = roundedTime % 60;

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
